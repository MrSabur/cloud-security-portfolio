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