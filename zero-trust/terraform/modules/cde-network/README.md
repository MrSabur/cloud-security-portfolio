# CDE Network Module

Creates an isolated Cardholder Data Environment (CDE) network for PCI-DSS compliance.

## Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                         CDE NETWORK                             │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    CDE Subnets                           │   │
│  │               (No Internet Access)                       │   │
│  │                                                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │   │
│  │  │Tokenization │→ │  Payment    │→ │   Card Vault    │  │   │
│  │  │   Service   │  │  Processor  │  │   (RDS)         │  │   │
│  │  │   (SG)      │  │   (SG)      │  │   (SG)          │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘  │   │
│  │         ▲                                                │   │
│  │         │ HTTPS only                                     │   │
│  │         │                                                │   │
│  └─────────┼────────────────────────────────────────────────┘   │
│            │                                                     │
│  ┌─────────┴─────────────────────────────────────────────────┐  │
│  │                    NACL Boundary                           │  │
│  │           (Explicit allow from app tier only)              │  │
│  └───────────────────────────────────────────────────────────┘  │
│            │                                                     │
│            │                                                     │
│  ┌─────────┴─────────────────────────────────────────────────┐  │
│  │               Application Tier                             │  │
│  │              (Out of PCI Scope)                            │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Key Security Controls

| Control | Implementation |
|---------|----------------|
| No internet access | No IGW or NAT route in CDE route table |
| AWS service access | VPC endpoints for KMS, Secrets Manager, etc. |
| Network boundary | NACL explicitly allows only app tier traffic |
| Service isolation | Security groups reference each other, not CIDRs |
| Audit trail | VPC Flow Logs with 365-day retention |

## Security Groups

Traffic flows in one direction only:
```
Application Tier → Tokenization → Payment Processor → Card Vault
                        ↓               ↓
                   VPC Endpoints   VPC Endpoints
```

## Usage
```hcl
module "cde_network" {
  source = "../../modules/cde-network"

  name                           = "novapay"
  vpc_id                         = module.vpc.vpc_id
  vpc_cidr_block                 = "10.0.0.0/16"
  cde_cidr_blocks                = ["10.0.100.0/24", "10.0.101.0/24"]
  availability_zones             = ["us-east-1a", "us-east-1b"]
  application_security_group_id  = module.app.security_group_id
  application_subnet_cidr_blocks = ["10.0.10.0/24", "10.0.11.0/24"]

  enable_vpc_endpoints    = true
  enable_flow_logs        = true
  flow_log_retention_days = 365
}
```

## PCI-DSS Compliance

| Requirement | Implementation |
|-------------|----------------|
| 1.3.1 - No direct public access | No internet route |
| 1.3.2 - Restrict outbound from CDE | NACL + SG egress rules |
| 1.4.1 - Firewall between zones | NACL boundary |
| 10.2 - Log network access | VPC Flow Logs |