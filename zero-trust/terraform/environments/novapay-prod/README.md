# NovaPay Production Environment

Production deployment of zero-trust payment processing architecture.

## Architecture
```
                         Internet
                            │
                            ▼
┌───────────────────────────────────────────────────────────────┐
│                      Public Subnets                           │
│                   10.0.0.0/24, 10.0.1.0/24                    │
│                                                               │
│   ┌─────────┐    ┌─────────┐    ┌─────────────────────────┐  │
│   │   ALB   │    │   NAT   │    │      API Gateway        │  │
│   │         │    │ Gateway │    │      + WAF              │  │
│   └─────────┘    └─────────┘    └─────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────────┐
│                  Application Subnets                          │
│               10.0.10.0/24, 10.0.11.0/24                      │
│                    (OUT OF PCI SCOPE)                         │
│                                                               │
│   Services work with TOKENS only - never see card numbers    │
└───────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────────┐
│                      CDE Subnets                              │
│               10.0.100.0/24, 10.0.101.0/24                    │
│                      (PCI SCOPE)                              │
│                                                               │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│   │Tokenization │  │  Payment    │  │    Card Vault       │  │
│   │  Service    │──│  Processor  │──│  (RDS + KMS)        │  │
│   │  (ECS)      │  │             │  │                     │  │
│   └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                               │
│   No Internet Access │ VPC Endpoints Only │ Encrypted        │
└───────────────────────────────────────────────────────────────┘
```

## Modules Used

| Module | Purpose |
|--------|---------|
| cde-network | Isolated CDE subnets, NACLs, VPC endpoints |
| secrets-management | KMS key, Secrets Manager |
| api-gateway | REST API, WAF, rate limiting |
| tokenization | ECS Fargate, RDS card vault |

## Prerequisites

1. AWS account with appropriate permissions
2. ECR repository with tokenization container image
3. Terraform >= 1.5.0

## Usage
```bash
# Initialize
terraform init

# Review plan
terraform plan

# Apply
terraform apply
```

## Remote State (Production)

Uncomment the backend configuration in `main.tf` and create:
```bash
# S3 bucket for state
aws s3 mb s3://novapay-terraform-state
aws s3api put-bucket-versioning \
  --bucket novapay-terraform-state \
  --versioning-configuration Status=Enabled

# DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

## Cost Estimate

| Component | Monthly Cost |
|-----------|--------------|
| VPC Endpoints (6 interface) | ~$85 |
| NAT Gateway | ~$32 |
| API Gateway | ~$50 |
| WAF | ~$25 |
| RDS (db.t3.medium, Multi-AZ) | ~$100 |
| ECS Fargate (2 tasks) | ~$30 |
| KMS + Secrets Manager | ~$10 |
| CloudWatch Logs | ~$20 |
| **Total** | **~$350/month** |

## Security Notes

- CDE has **no internet access** - only VPC endpoints
- All secrets in Secrets Manager - no hardcoded credentials
- KMS encryption for card data at rest
- WAF protects API from common attacks
- VPC Flow Logs retained 365 days for audit