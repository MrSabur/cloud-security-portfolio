# ADR-002: Network Segmentation and CDE Isolation

## Status
Accepted

## Context

NovaPay processes credit card transactions. PCI-DSS requires that systems storing, processing, or transmitting cardholder data (CHD) must be isolated in a Cardholder Data Environment (CDE) with strict access controls.

Current state problems:
- All services in a single VPC with permissive security groups
- Card data flows through multiple services without encryption
- No network-level separation between sensitive and non-sensitive workloads
- Developers can access any service from their VPN connection

PCI-DSS Network Requirements:
- **1.2:** Restrict connections between untrusted networks and CDE
- **1.3:** Prohibit direct public access to CDE
- **1.4:** No unauthorized traffic between CDE and other networks
- **4.1:** Use strong cryptography for CHD transmission over open networks

### The Cost of Getting This Wrong

If the entire infrastructure is in PCI scope:
- Every server, container, and database must meet PCI standards
- Every engineer with access needs background checks and training
- Audit scope expands from weeks to months
- Compliance costs: $500K+/year

If CDE is properly isolated:
- Only CDE systems are in scope
- Reduced audit footprint (days, not weeks)
- Compliance costs: $50-100K/year

**Proper network segmentation reduces PCI scope by 80%+.**

## Decision

### Three-Zone Architecture

Implement network segmentation with three security zones:
```
┌─────────────────────────────────────────────────────────────────────┐
│                         VPC: 10.0.0.0/16                            │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                     PUBLIC ZONE                                │ │
│  │                     10.0.0.0/24                                │ │
│  │                                                                │ │
│  │   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │ │
│  │   │     ALB     │    │     WAF     │    │  API GW     │       │ │
│  │   └─────────────┘    └─────────────┘    └─────────────┘       │ │
│  │                                                                │ │
│  │   Internet-facing │ DDoS protection │ Rate limiting           │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                               │                                     │
│                               ▼                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                   APPLICATION ZONE                             │ │
│  │              10.0.10.0/24, 10.0.11.0/24                        │ │
│  │                   (OUT OF PCI SCOPE)                           │ │
│  │                                                                │ │
│  │   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │ │
│  │   │  Merchant   │    │  Webhook    │    │  Reporting  │       │ │
│  │   │   Service   │    │   Service   │    │   Service   │       │ │
│  │   └─────────────┘    └─────────────┘    └─────────────┘       │ │
│  │                                                                │ │
│  │   Works with TOKENS only │ Cannot see card numbers            │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                               │                                     │
│                               │ Tokenized requests only             │
│                               ▼                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │               CARDHOLDER DATA ENVIRONMENT (CDE)                │ │
│  │                     10.0.100.0/24                              │ │
│  │                      (PCI SCOPE)                               │ │
│  │                                                                │ │
│  │   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │ │
│  │   │Tokenization │    │  Payment    │    │ Card Vault  │       │ │
│  │   │  Service    │───▶│  Processor  │───▶│  (KMS/HSM)  │       │ │
│  │   └─────────────┘    └─────────────┘    └─────────────┘       │ │
│  │                                                                │ │
│  │   Mutual TLS │ No internet │ Encrypted storage │ HSM keys     │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Zone Definitions

| Zone | CIDR | PCI Scope | Purpose | Internet Access |
|------|------|-----------|---------|-----------------|
| Public | 10.0.0.0/24 | No | Load balancers, WAF, API Gateway | Inbound only |
| Application | 10.0.10.0/24, 10.0.11.0/24 | No | Business logic, works with tokens | Outbound via NAT |
| CDE | 10.0.100.0/24 | **Yes** | Card processing, tokenization, vault | **None** |

### Traffic Flow Rules

**Principle: Traffic flows inward, never outward from CDE.**
```
Internet → Public Zone:     ALLOWED (via ALB/API GW)
Public → Application:       ALLOWED (specific ports)
Application → CDE:          ALLOWED (tokenization API only)
CDE → Application:          RESPONSES ONLY (stateful)
CDE → Internet:             DENIED (no egress)
Application → Application:  ALLOWED (service mesh)
CDE → CDE:                  ALLOWED (internal only)
```

### Security Group Strategy

**Security groups reference other security groups, not CIDR blocks.**
```hcl
# CDE Security Group - only allows traffic from tokenization service
resource "aws_security_group" "cde" {
  name        = "cde-sg"
  description = "Cardholder Data Environment - PCI Scope"
  vpc_id      = aws_vpc.main.id

  # Only tokenization service can reach CDE
  ingress {
    from_port                = 443
    to_port                  = 443
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.tokenization.id
    description              = "Tokenization service only"
  }

  # No internet egress - critical for PCI
  # Egress only to VPC endpoints

  tags = {
    Name       = "cde-sg"
    PCI_Scope  = "true"
    Compliance = "pci-dss"
  }
}
```

**Why security group references?**
- Self-documenting: "Tokenization service can access CDE"
- Self-healing: If service moves to new IP, rules still work
- Auditable: QSA can see exactly which services have access
- Prevents mistakes: Can't accidentally open to wrong CIDR

### CDE Egress: VPC Endpoints Only

**The CDE has no internet access.** All external communication via VPC endpoints:
```
┌─────────────────────────────────────────────────────────────────┐
│                     CDE Subnet                                  │
│                                                                 │
│  ┌─────────────────┐                                           │
│  │ Payment Service │                                           │
│  └────────┬────────┘                                           │
│           │                                                     │
│           │ Private connection (no internet)                    │
│           ▼                                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              VPC Endpoints (Interface Type)              │   │
│  │                                                          │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────────┐   │   │
│  │  │   KMS   │ │ Secrets │ │   STS   │ │ CloudWatch  │   │   │
│  │  │         │ │ Manager │ │         │ │    Logs     │   │   │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────────┘   │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  No NAT Gateway │ No Internet Gateway │ Endpoints only         │
└─────────────────────────────────────────────────────────────────┘
```

**Required VPC Endpoints for CDE:**

| Endpoint        | Type      | Purpose           |
|-----------------|-----------|-------------------|
| KMS             | Interface | Decrypt card data |
| Secrets Manager | Interface | Retrieve API credentials |
| STS             | Interface | Assume roles |
| CloudWatch Logs | Interface | Ship logs without internet |
| ECR             | Interface | Pull container images |
| S3              | Gateway   | Access encrypted backups |

**Cost:** ~$7/endpoint/AZ/month = ~$85/month for CDE endpoints (two AZs)

### Network ACLs: Defense in Depth

Security groups are stateful. NACLs add stateless layer:
```hcl
# NACL for CDE subnet - explicit deny for non-CDE traffic
resource "aws_network_acl" "cde" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.cde.id]

  # Allow inbound from Application zone only
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.10.0/23"  # Application zone
    from_port  = 443
    to_port    = 443
  }

  # Allow return traffic (ephemeral ports)
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "10.0.10.0/23"
    from_port  = 1024
    to_port    = 65535
  }

  # Explicit deny all other inbound
  ingress {
    protocol   = -1
    rule_no    = 999
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Allow outbound to VPC endpoints only (10.0.200.0/24)
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.200.0/24"  # VPC endpoints subnet
    from_port  = 443
    to_port    = 443
  }

  # Deny all other outbound
  egress {
    protocol   = -1
    rule_no    = 999
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name      = "cde-nacl"
    PCI_Scope = "true"
  }
}
```

**Why both Security Groups AND NACLs?**

| Layer          | Type      | Use Case |
|----------------|-----------|----------|
| Security Group | Stateful  | Primary access control, service-to-service |
| NACL           | Stateless | Subnet-level boundary, explicit deny, defense in depth |

If someone misconfigures a security group, the NACL still blocks unauthorized traffic.

### Flow Logs: Network Audit Trail
```hcl
resource "aws_flow_log" "cde" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.cde_flow_logs.arn
  iam_role_arn             = aws_iam_role.flow_logs.arn

  # Custom format for PCI audit requirements
  log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status}"

  tags = {
    Name      = "cde-flow-logs"
    Retention = "365-days"
    PCI_Scope = "true"
  }
}
```

**PCI-DSS 10.2 requires:** Log all access to cardholder data. Flow logs capture:
- Source/destination IP
- Allowed/denied traffic
- Timestamp
- Bytes transferred

## Consequences

### Positive

- **80% PCI scope reduction:** Only CDE systems require full PCI controls
- **Defense in depth:** Security groups + NACLs + no internet
- **Audit-ready:** Flow logs prove network isolation
- **Breach containment:** Compromised application service cannot reach card data directly
- **Clear boundaries:** Developers know which systems are sensitive

### Negative

- **VPC endpoint costs:** ~$85/month for CDE isolation
- **Complexity:** Three zones require careful routing
- **Deployment friction:** CDE changes require security review

### Cost Analysis

| Component | Monthly Cost |
|-----------|--------------|
| VPC Endpoints (CDE) | ~$85 |
| NAT Gateway (App zone) | ~$32 |
| Flow Logs storage | ~$10 |
| **Total** | **~$130/month** |

**vs. Full-scope PCI audit:** $200K+ in compliance costs

## Alternatives Considered

### Alternative 1: Single VPC, Security Groups Only

**Rejected because:**
- No network-level isolation
- Single misconfigured SG exposes CDE
- Auditors require network segmentation for scope reduction

### Alternative 2: Separate VPCs with Peering

**Rejected because:**
- VPC peering is less flexible than subnets with NACLs
- Additional complexity for small environment
- Can migrate to multi-VPC later if needed

### Alternative 3: AWS PrivateLink for CDE Access

**Considered for future:**
- PrivateLink exposes CDE as a service endpoint
- Even stronger isolation (CDE becomes its own VPC)
- Deferred: Current NACL approach sufficient for initial certification

## PCI-DSS Compliance Mapping

| Requirement | Implementation |
|-------------|----------------|
| 1.2.1 - Restrict inbound traffic to CDE | Security groups allow only tokenization service |
| 1.3.1 - No direct public access to CDE | CDE in private subnet, no IGW route |
| 1.3.2 - No unauthorized outbound from CDE | NACL denies all egress except VPC endpoints |
| 1.4.1 - Firewall between wireless and CDE | N/A (no wireless in AWS) |
| 4.1 - Encrypt CHD over public networks | TLS 1.2+ enforced at ALB; mTLS within CDE |
| 10.2 - Log access to CDE | VPC Flow Logs with 365-day retention |

## References

- [PCI-DSS Network Segmentation Guidance](https://www.pcisecuritystandards.org/documents/Guidance-PCI-DSS-Scoping-and-Segmentation_v1_1.pdf)
- [AWS PCI-DSS Compliance Guide](https://docs.aws.amazon.com/whitepapers/latest/pci-dss-scoping-on-aws/pci-dss-scoping-on-aws.html)
- [VPC Endpoints Documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/)