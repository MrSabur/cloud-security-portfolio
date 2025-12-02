# Cloud Security Portfolio

Production-grade AWS architectures demonstrating enterprise security patterns.

## Projects

### AWS Landing Zone
Multi-account architecture with Transit Gateway networking, IAM permission boundaries, and centralized security controls. Designed for HIPAA compliance.

### Zero-Trust Reference Architecture
Five-pillar zero-trust implementation using AWS-native controls: identity, device, network, application, and data security layers.

## Author
**Afolabi Ajao** — Cloud Security Architect  
[LinkedIn](https://linkedin.com/in/afolabisaburajao) | CISSP | CCSP | AWS Solutions Architect

## Tech Stack
- Terraform (Infrastructure as Code)
- AWS (Primary cloud provider)
- GitHub Actions (CI/CD)

## Compliance Mappings
- NIST Cybersecurity Framework
- HIPAA Security Rule

# VPC Module

Creates a three-tier VPC designed for HIPAA-compliant healthcare workloads.

## Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                         VPC                                 │
│                                                             │
│  ┌─────────────────────┐     ┌─────────────────────┐       │
│  │   Public Subnet     │     │   Public Subnet     │       │
│  │   (ALB, NAT GW)     │     │   (ALB, NAT GW)     │       │
│  │      AZ-a           │     │      AZ-b           │       │
│  └─────────────────────┘     └─────────────────────┘       │
│                                                             │
│  ┌─────────────────────┐     ┌─────────────────────┐       │
│  │   Private Subnet    │     │   Private Subnet    │       │
│  │   (App servers)     │     │   (App servers)     │       │
│  │      AZ-a           │     │      AZ-b           │       │
│  └─────────────────────┘     └─────────────────────┘       │
│                                                             │
│  ┌─────────────────────┐     ┌─────────────────────┐       │
│  │    Data Subnet      │     │    Data Subnet      │       │
│  │   (RDS, no internet)│     │   (RDS, no internet)│       │
│  │      AZ-a           │     │      AZ-b           │       │
│  └─────────────────────┘     └─────────────────────┘       │
│                                                             │
│  VPC Endpoints: S3 (gateway), DynamoDB (gateway)           │
└─────────────────────────────────────────────────────────────┘
```

## Features

- **Three-tier subnet architecture**: Public, Private, and Data tiers with appropriate routing
- **HIPAA-compliant data tier**: No internet access for database subnets
- **Configurable NAT Gateway**: Single (cost-optimized) or multi-AZ (high availability)
- **VPC Flow Logs**: All traffic logged to CloudWatch with configurable retention
- **VPC Endpoints**: S3 and DynamoDB gateway endpoints (free) for private access

## Usage
```hcl
module "vpc" {
  source = "../../modules/vpc"

  name        = "prod"
  cidr_block  = "10.20.0.0/16"
  environment = "production"

  enable_nat_gateway = true
  single_nat_gateway = false  # Multi-AZ for production

  enable_flow_logs        = true
  flow_log_retention_days = 365
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name prefix for all resources | string | - | yes |
| cidr_block | CIDR block for the VPC | string | - | yes |
| environment | Environment name | string | - | yes |
| availability_zones | List of AZs to use | list(string) | [] (auto) | no |
| enable_nat_gateway | Create NAT Gateway(s) | bool | true | no |
| single_nat_gateway | Use single NAT (cost savings) | bool | false | no |
| enable_flow_logs | Enable VPC Flow Logs | bool | true | no |
| flow_log_retention_days | Days to retain flow logs | number | 365 | no |
| tags | Additional tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| vpc_cidr_block | The CIDR block of the VPC |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| data_subnet_ids | List of data subnet IDs |
| nat_gateway_ids | List of NAT Gateway IDs |
| nat_gateway_public_ips | List of NAT Gateway public IPs |

## Cost Estimate

| Component | Single NAT | Multi-AZ NAT |
|-----------|------------|--------------|
| NAT Gateway | $32/month | $64/month |
| Data Processing | $0.045/GB | $0.045/GB |
| VPC Flow Logs | ~$0.50/GB ingested | ~$0.50/GB ingested |
| VPC Endpoints (Gateway) | Free | Free |

## Compliance

### HIPAA

- Data tier has no internet route (PHI cannot be directly exfiltrated)
- All network traffic logged via VPC Flow Logs
- Encryption in transit enforced at application layer (ALB with TLS)

### NIST CSF

- PR.AC-5: Network segmentation via three-tier architecture
- PR.DS-2: Data-in-transit protection via private subnets
- DE.CM-1: Network monitoring via Flow Logs

# Transit Gateway Module

Creates a Transit Gateway hub with route table isolation for environment separation.

## Architecture
```
                    ┌─────────────────────────────────────────┐
                    │           TRANSIT GATEWAY               │
                    │                                         │
                    │  ┌─────────┐ ┌─────────┐ ┌─────────┐   │
                    │  │ Prod RT │ │ Dev RT  │ │Shared RT│   │
                    │  └─────────┘ └─────────┘ └─────────┘   │
                    └─────────────────────────────────────────┘
                           │            │            │
          ┌────────────────┴────────────┴────────────┴────────┐
          │                      │                            │
          ▼                      ▼                            ▼
     ┌─────────┐           ┌──────────┐                 ┌──────────┐
     │Workloads│           │Workloads │                 │ Security │
     │  Prod   │           │   Dev    │                 │ + Shared │
     └─────────┘           └──────────┘                 └──────────┘
```

## Isolation Model

| Source | Can Reach | Cannot Reach |
|--------|-----------|--------------|
| Prod VPC | Security, Shared Services, Internet (via NAT) | Dev VPC |
| Dev VPC | Security, Shared Services, Internet (via NAT) | Prod VPC |
| Security VPC | All VPCs (for log collection) | - |
| Shared Services | All VPCs (for CI/CD, DNS) | - |

## Usage
```hcl
module "transit_gateway" {
  source = "../../modules/transit-gateway"

  name        = "medflow"
  environment = "shared"

  tags = {
    CostCenter = "infrastructure"
  }
}

# Then attach VPCs using aws_ec2_transit_gateway_vpc_attachment
# and associate with appropriate route tables
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name prefix for resources | string | - | yes |
| environment | Environment for tagging | string | "shared" | no |
| amazon_side_asn | Private ASN for BGP | number | 64512 | no |
| enable_dns_support | Enable DNS resolution | bool | true | no |
| enable_auto_accept_shared_attachments | Auto-accept cross-account attachments | bool | false | no |
| tags | Additional tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| transit_gateway_id | ID of the Transit Gateway |
| transit_gateway_arn | ARN of the Transit Gateway |
| prod_route_table_id | Route table for production workloads |
| dev_route_table_id | Route table for development workloads |
| shared_route_table_id | Route table for security and shared services |
| ram_share_arn | RAM share ARN for cross-account access |

## Cost Estimate

| Component | Cost |
|-----------|------|
| Transit Gateway | $0.05/hour (~$36/month) |
| Per VPC Attachment | $0.05/hour (~$36/month each) |
| Data Processing | $0.02/GB |

**Example (4 VPCs):** $36 (TGW) + $144 (4 attachments) + data = ~$180/month + data transfer

## Cross-Account Setup

Transit Gateway lives in the Shared Services account. Other accounts attach via:

1. RAM share accepts the account/OU
2. Workload account creates `aws_ec2_transit_gateway_vpc_attachment`
3. Shared Services account associates attachment with correct route table
4. Routes added to both TGW route tables and VPC route tables

## Compliance Notes

- **Network Isolation**: Prod/Dev cannot communicate at the network layer
- **Audit Trail**: VPC Flow Logs capture all cross-VPC traffic
- **Least Privilege**: Attachments must be explicitly approved (auto-accept disabled)

# Transit Gateway Attachment Module

Connects a VPC to an existing Transit Gateway and configures routing.

## What This Module Does

1. **Creates TGW Attachment**: Connects the VPC to the Transit Gateway via specified subnets
2. **Associates Route Table**: Links the attachment to the correct TGW route table (prod/dev/shared)
3. **Propagates Routes**: Advertises the VPC's CIDR to the TGW route table
4. **Configures VPC Routes**: Adds routes in the VPC pointing to the TGW

## Usage
```hcl
module "vpc_attachment" {
  source = "../../modules/tgw-attachment"

  name                           = "prod"
  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnet_ids
  transit_gateway_id             = data.aws_ec2_transit_gateway.main.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.prod.id

  vpc_route_table_ids = concat(
    module.vpc.private_route_table_ids,
    [module.vpc.data_route_table_id]
  )

  # CIDRs of other VPCs to route through TGW
  destination_cidr_blocks = [
    "10.0.0.0/16",   # Security VPC
    "10.1.0.0/16",   # Shared Services VPC
  ]
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|:--------:|
| name | Name prefix | string | yes |
| vpc_id | VPC to attach | string | yes |
| subnet_ids | Subnets for attachment | list(string) | yes |
| transit_gateway_id | TGW to attach to | string | yes |
| transit_gateway_route_table_id | TGW route table for association | string | yes |
| vpc_route_table_ids | VPC route tables needing TGW routes | list(string) | yes |
| destination_cidr_blocks | CIDRs to route through TGW | list(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| attachment_id | ID of the TGW attachment |
| vpc_id | ID of the attached VPC |

## Architecture Note

Place the attachment in **private subnets**, not public. The TGW attachment creates an ENI in each subnet—these don't need internet access.

# Security Baseline Module

Implements core security controls for HIPAA-compliant AWS environments.

## Components

### CloudTrail
- Multi-region API audit logging
- Log file integrity validation (tamper detection)
- S3 storage with encryption and lifecycle policies
- 7-year retention (HIPAA requirement)

### GuardDuty
- ML-based threat detection
- S3 protection (detects suspicious access patterns)
- EBS malware scanning
- Kubernetes audit log analysis
- 15-minute finding publication

### AWS Config
- Continuous configuration recording
- HIPAA-focused compliance rules:
  - S3 public access prohibited
  - S3/EBS/RDS encryption required
  - VPC Flow Logs enabled
  - MFA required for IAM users and root

### Security Hub
- Centralized findings dashboard
- Enabled standards:
  - AWS Foundational Security Best Practices
  - CIS AWS Foundations Benchmark
  - NIST 800-53
- GuardDuty integration

## Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                      SECURITY ACCOUNT                           │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │ CloudTrail  │  │  GuardDuty  │  │      Security Hub       │ │
│  │   Logs      │  │  Findings   │  │   (Aggregated View)     │ │
│  │     │       │  │      │      │  │           ▲             │ │
│  │     ▼       │  │      ▼      │  │           │             │ │
│  │ ┌───────┐   │  │  ┌───────┐  │  │  Findings from all      │ │
│  │ │  S3   │   │  │  │ S.Hub │──┼──│  accounts flow here     │ │
│  │ │Bucket │   │  │  └───────┘  │  │                         │ │
│  │ └───────┘   │  │             │  └─────────────────────────┘ │
│  └─────────────┘  └─────────────┘                               │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                     AWS Config                           │   │
│  │  Rules: S3 encryption, RDS encryption, VPC flow logs,   │   │
│  │         MFA enabled, no public access                    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Usage
```hcl
module "security_baseline" {
  source = "../../modules/security-baseline"

  name                      = "medflow"
  cloudtrail_s3_bucket_name = "medflow-cloudtrail-logs-123456789012"
  config_s3_bucket_name     = "medflow-config-snapshots-123456789012"

  # All services enabled by default
  enable_cloudtrail   = true
  enable_guardduty    = true
  enable_config       = true
  enable_security_hub = true
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| name | Name prefix | string | - |
| cloudtrail_s3_bucket_name | Bucket for CloudTrail logs | string | - |
| config_s3_bucket_name | Bucket for Config snapshots | string | - |
| cloudtrail_retention_days | Log retention period | number | 2555 |
| enable_cloudtrail | Enable CloudTrail | bool | true |
| enable_guardduty | Enable GuardDuty | bool | true |
| enable_config | Enable AWS Config | bool | true |
| enable_security_hub | Enable Security Hub | bool | true |

## Outputs

| Name | Description |
|------|-------------|
| cloudtrail_arn | ARN of CloudTrail |
| cloudtrail_s3_bucket_name | CloudTrail log bucket |
| guardduty_detector_id | GuardDuty detector ID |
| config_recorder_id | Config recorder ID |
| security_hub_arn | Security Hub ARN |

## Cost Estimate

| Component | Estimated Cost |
|-----------|---------------|
| CloudTrail | Free (first trail) + S3 storage |
| GuardDuty | ~$4/million events analyzed |
| AWS Config | $0.003/rule evaluation + S3 |
| Security Hub | $0.0010/finding (first 10K free) |

**Typical small environment:** $50-150/month

## HIPAA Compliance Mapping

| HIPAA Requirement | Implementation |
|-------------------|----------------|
| §164.312(b) Audit controls | CloudTrail with integrity validation |
| §164.308(a)(1) Risk analysis | Security Hub compliance dashboard |
| §164.308(a)(6) Security incidents | GuardDuty threat detection |
| §164.308(a)(8) Evaluation | AWS Config continuous compliance |
| §164.312(a)(1) Access controls | Config rules for IAM/MFA |
| §164.312(e)(1) Transmission security | Config rules for encryption |

# Cloud Security Portfolio

Production-grade AWS architectures demonstrating enterprise security patterns for HIPAA-compliant healthcare environments.

## 🏗️ Projects

### AWS Landing Zone

Multi-account architecture with Transit Gateway networking, IAM permission boundaries, and centralized security controls.

**[View Landing Zone →](landing-zone/)**

#### Architecture Overview
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AWS ORGANIZATION                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │
│  │    SECURITY     │  │ SHARED SERVICES │  │         WORKLOADS          │ │
│  │    ACCOUNT      │  │    ACCOUNT      │  │                            │ │
│  │                 │  │                 │  │  ┌─────────┐ ┌─────────┐   │ │
│  │ • CloudTrail    │  │ • Transit GW    │  │  │  PROD   │ │   DEV   │   │ │
│  │ • GuardDuty     │  │ • NAT Gateway   │  │  │  VPC    │ │   VPC   │   │ │
│  │ • Config        │  │ • DNS           │  │  │         │ │         │   │ │
│  │ • Security Hub  │  │ • CI/CD         │  │  └─────────┘ └─────────┘   │ │
│  │                 │  │                 │  │       │           │        │ │
│  └────────┬────────┘  └────────┬────────┘  └───────┼───────────┼────────┘ │
│           │                    │                   │           │          │
│           └────────────────────┴───────────────────┴───────────┘          │
│                                │                                          │
│                    ┌───────────┴───────────┐                              │
│                    │    TRANSIT GATEWAY    │                              │
│                    │    (Network Hub)      │                              │
│                    └───────────────────────┘                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Key Features

| Feature | Description |
|---------|-------------|
| **Multi-Account Isolation** | Blast radius containment via AWS Organizations |
| **Network Segmentation** | Transit Gateway with route table isolation (prod ↔ dev blocked) |
| **Three-Tier VPCs** | Public, Private, Data subnets with defense in depth |
| **HIPAA Compliance** | 7-year log retention, encryption at rest, audit controls |
| **Security Baseline** | GuardDuty, Security Hub, AWS Config with compliance rules |

#### Modules

| Module | Purpose |
|--------|---------|
| [vpc](landing-zone/terraform/modules/vpc/) | Three-tier VPC with NAT, flow logs, VPC endpoints |
| [transit-gateway](landing-zone/terraform/modules/transit-gateway/) | Hub-and-spoke networking with route table isolation |
| [tgw-attachment](landing-zone/terraform/modules/tgw-attachment/) | VPC-to-TGW connectivity |
| [security-baseline](landing-zone/terraform/modules/security-baseline/) | CloudTrail, GuardDuty, Config, Security Hub |

#### Design Decisions

- [ADR-001: Multi-Account Strategy](landing-zone/docs/decisions/001-multi-account-strategy.md)
- [ADR-002: Network Topology](landing-zone/docs/decisions/002-network-topology.md)

---

## 🛡️ Compliance Mapping

| Framework | Coverage |
|-----------|----------|
| **HIPAA Security Rule** | Access controls, audit controls, transmission security, encryption |
| **NIST CSF** | PR.AC (Access Control), PR.DS (Data Security), DE.CM (Monitoring) |
| **CIS AWS Benchmark** | Security Hub automated checks |

---

## 💰 Cost Estimate

| Component | Monthly Cost |
|-----------|--------------|
| Transit Gateway (hub + 4 attachments) | ~$180 |
| NAT Gateways (2 in shared services) | ~$64 |
| VPC Flow Logs | ~$20 |
| GuardDuty | ~$50 |
| AWS Config | ~$30 |
| Security Hub | ~$10 |
| **Total** | **~$350/month** |

*Estimate for small environment. Production costs vary with data transfer and resource count.*

---

## 🚀 Getting Started

### Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured
- AWS Organizations set up

### Deployment Order
```bash
# 1. Security Account (logging infrastructure)
cd landing-zone/terraform/environments/security
terraform init && terraform plan

# 2. Shared Services (Transit Gateway hub)
cd ../shared-services
terraform init && terraform plan

# 3. Workload Accounts (attach to TGW)
cd ../workloads-prod
terraform init && terraform plan
```

---

## 👤 Author

**Sabur Ajao** — Cloud Security Architect

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue)](https://linkedin.com/in/afolabisaburajao)

**Credentials:** CISSP | CCSP | AWS Solutions Architect | ISO 27032 | MBA (Kellogg)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.