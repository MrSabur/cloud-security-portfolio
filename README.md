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