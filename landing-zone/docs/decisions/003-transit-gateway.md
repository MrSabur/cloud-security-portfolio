# ADR-003: Transit Gateway Architecture

## Status
Accepted

## Context

MedFlow's multi-account strategy (ADR-001) creates four isolated AWS accounts. These accounts need controlled network connectivity:

- Workloads-Prod must reach Shared Services (CI/CD, DNS) and Security (log aggregation)
- Workloads-Dev must reach Shared Services and Security
- Workloads-Prod and Workloads-Dev must **never** communicate directly
- All accounts need outbound internet access via centralized NAT

The network topology (ADR-002) established the high-level design. This ADR documents the specific Transit Gateway implementation decisions.

## Decision

### Use Transit Gateway as Central Hub

Implement AWS Transit Gateway in the Shared Services account as the central network hub, with spoke VPCs in each account.
```
                    ┌─────────────────────────────────────────┐
                    │           TRANSIT GATEWAY               │
                    │         (Shared Services Acct)          │
                    │                                         │
                    │  ┌─────────┐ ┌─────────┐ ┌─────────┐   │
                    │  │ Prod RT │ │ Dev RT  │ │SharedRT │   │
                    │  └─────────┘ └─────────┘ └─────────┘   │
                    └─────────────────────────────────────────┘
                           │            │            │
          ┌────────────────┴────────────┴────────────┴────────┐
          ▼                ▼            ▼                     ▼
     ┌─────────┐     ┌─────────┐  ┌─────────┐          ┌─────────┐
     │Security │     │ Shared  │  │Workloads│          │Workloads│
     │  VPC    │     │Services │  │   Dev   │          │  Prod   │
     └─────────┘     └─────────┘  └─────────┘          └─────────┘
```

### Route Table Isolation

Create three Transit Gateway route tables to enforce environment separation:

| Route Table | Associated VPCs | Can Route To | Cannot Route To |
|-------------|-----------------|--------------|-----------------|
| Prod RT | Workloads-Prod | Security, Shared Services | Workloads-Dev |
| Dev RT | Workloads-Dev | Security, Shared Services | Workloads-Prod |
| Shared RT | Security, Shared Services | All VPCs | - |

**Isolation mechanism:** A VPC associated with Prod RT has no route entry for the Dev VPC CIDR (10.10.0.0/16). Even if an application attempts to connect, the Transit Gateway has no path to forward the traffic.

### Cross-Account Sharing via RAM

Transit Gateway lives in Shared Services account. Other accounts connect via AWS Resource Access Manager (RAM):

1. Shared Services creates RAM share containing Transit Gateway
2. RAM share is shared with Organization (or specific OUs)
3. Workload accounts create `aws_ec2_transit_gateway_vpc_attachment`
4. Shared Services associates attachment with appropriate route table

**Security control:** `auto_accept_shared_attachments = false` — attachments require explicit approval, preventing unauthorized VPCs from joining the network.

### Disable Default Route Table
```hcl
default_route_table_association = "disable"
default_route_table_propagation = "disable"
```

**Rationale:** Default route table would allow any attached VPC to communicate with any other. By disabling defaults, every attachment must be explicitly associated with a specific route table—preventing accidental cross-environment connectivity.

### Centralized Egress

All internet-bound traffic routes through Shared Services VPC:
```
Workload VPC → TGW → Shared Services VPC → NAT Gateway → Internet
```

**Benefits:**
- Single NAT Gateway pair instead of per-VPC NAT ($64/month vs $256/month)
- Centralized egress monitoring point
- Future: Add AWS Network Firewall for egress filtering

**Tradeoff:** Additional network hop adds ~1ms latency. Acceptable for healthcare workloads where security > latency.

## Consequences

### Positive

- **Hard network isolation:** Prod and Dev cannot communicate even if IAM policies are misconfigured
- **Scalable:** Adding VPCs requires only new attachment + route table association
- **Cost efficient:** Centralized NAT reduces monthly spend by ~$200
- **Auditable:** All cross-VPC traffic traverses TGW, visible in flow logs
- **Future-proof:** Can add VPN/Direct Connect to TGW for hybrid connectivity

### Negative

- **Transit Gateway cost:** ~$36/month base + $36/month per attachment
- **Complexity:** Cross-account networking requires RAM shares and careful route management
- **Single region:** Transit Gateway is regional; multi-region requires TGW peering

### Cost Analysis

| Component | Monthly Cost |
|-----------|--------------|
| Transit Gateway | $36 |
| 4 VPC Attachments | $144 |
| Data Processing | $0.02/GB |
| **Total (before data)** | **$180/month** |

vs. Alternative (VPC Peering + per-VPC NAT):
- VPC Peering: Free
- 4 NAT Gateways: $256/month
- No centralized routing/monitoring

**TGW is more expensive but provides network isolation that VPC Peering cannot.**

## Alternatives Considered

### Alternative 1: VPC Peering

**Rejected because:**
- No transitive routing (A↔B and B↔C ≠ A↔C)
- Cannot enforce route table isolation between environments
- N VPCs require N(N-1)/2 peering connections (doesn't scale)
- No centralized egress point

### Alternative 2: AWS PrivateLink Only

**Rejected because:**
- Service-to-service connectivity only, not general networking
- Would require endpoint per service per VPC
- Cannot route arbitrary traffic between VPCs

### Alternative 3: VPN Mesh

**Rejected because:**
- Operational complexity
- Bandwidth limitations
- Not designed for VPC-to-VPC within AWS

## Compliance Mapping

| Requirement | Implementation |
|-------------|----------------|
| HIPAA §164.312(e)(1) - Transmission security | Traffic between VPCs encrypted in transit (AWS backbone) |
| HIPAA §164.312(a)(1) - Access controls | Route table isolation prevents unauthorized network paths |
| NIST PR.AC-5 - Network integrity | Segmentation enforced at infrastructure layer |
| NIST PR.PT-4 - Communications protection | Centralized egress enables monitoring and filtering |

## References

- [AWS Transit Gateway Documentation](https://docs.aws.amazon.com/vpc/latest/tgw/)
- [AWS RAM Documentation](https://docs.aws.amazon.com/ram/latest/userguide/)
- [Transit Gateway vs VPC Peering](https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/transit-gateway-vs-vpc-peering.html)