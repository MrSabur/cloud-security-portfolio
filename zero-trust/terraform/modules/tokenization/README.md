# Tokenization Module

Core service for converting card numbers to tokens. Implements PCI-DSS compliant card vault with ECS Fargate and RDS PostgreSQL.

## Architecture
```
Application Tier
       │
       │ HTTPS (tokens only)
       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TOKENIZATION SERVICE                         │
│                      (ECS Fargate)                              │
│                                                                 │
│  Card In → Validate → Generate Token → Encrypt PAN → Store     │
│                                                                 │
│  Token Out ← Return Token ← Save Mapping                       │
└─────────────────────────────────────────────────────────────────┘
       │
       │ PostgreSQL (encrypted)
       ▼
┌─────────────────────────────────────────────────────────────────┐
│                       CARD VAULT                                │
│                    (RDS PostgreSQL)                             │
│                                                                 │
│  token (PK) │ encrypted_pan │ last_four │ fingerprint │ ...   │
│                                                                 │
│  Storage encrypted with KMS │ Multi-AZ │ 35-day backups        │
└─────────────────────────────────────────────────────────────────┘
```

## Security Controls

| Control | Implementation |
|---------|----------------|
| No internet | Runs in CDE subnet with no NAT/IGW route |
| Encryption at rest | RDS + KMS (AES-256) |
| Encryption in transit | TLS 1.2+ enforced |
| Least privilege | IAM roles scoped to specific resources |
| No SSH | ECS Exec via Session Manager (audited) |
| Secrets | Database credentials in Secrets Manager |

## Usage
```hcl
module "tokenization" {
  source = "../../modules/tokenization"

  name        = "novapay"
  environment = "live"

  # Network (CDE)
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.cde_network.cde_subnet_ids
  security_group_id = module.cde_network.tokenization_security_group_id

  # Container
  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/novapay-tokenization:latest"
  cpu             = 512
  memory          = 1024
  desired_count   = 2

  # Database
  database_subnet_ids        = module.cde_network.cde_subnet_ids
  database_security_group_id = module.cde_network.card_vault_security_group_id
  database_instance_class    = "db.t3.medium"
  database_multi_az          = true

  # Encryption
  kms_key_arn = module.secrets.kms_key_arn

  # Secrets
  database_credentials_secret_arn = module.secrets.secret_arns["database/card-vault"]
}
```

## Internal DNS

The service registers with Cloud Map for internal discovery:
```
tokenization.{name}.cde.internal
```

Other CDE services can reach tokenization via this DNS name without hardcoding IPs.

## PCI-DSS Compliance

| Requirement | Implementation |
|-------------|----------------|
| 3.4 - Render PAN unreadable | KMS encryption (AES-256-GCM) |
| 3.5 - Protect encryption keys | KMS with strict IAM policy |
| 3.6 - Key management | Automatic rotation enabled |
| 7.1 - Limit access | IAM roles with least-privilege |
| 8.6 - Unique service accounts | Each service has dedicated IAM role |
| 10.2 - Log access | CloudWatch logs with 365-day retention |

## Cost Estimate

| Component | Monthly Cost |
|-----------|--------------|
| ECS Fargate (2 tasks, 0.5 vCPU, 1GB) | ~$30 |
| RDS db.t3.medium (Multi-AZ) | ~$100 |
| RDS storage (20GB) | ~$5 |
| CloudWatch Logs | ~$10 |
| **Total** | **~$145/month** |