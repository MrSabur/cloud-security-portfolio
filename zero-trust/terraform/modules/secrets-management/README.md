# Secrets Management Module

Centralized secrets management with AWS KMS encryption and Secrets Manager.

## Features

- Customer-managed KMS key with automatic rotation
- Secrets Manager with configurable recovery window
- Optional secret rotation with Lambda
- IAM policy for secure secret access

## Usage
```hcl
module "secrets" {
  source = "../../modules/secrets-management"

  name        = "novapay"
  environment = "production"

  # KMS configuration
  create_kms_key       = true
  enable_key_rotation  = true
  key_user_role_arns   = [
    aws_iam_role.tokenization.arn,
    aws_iam_role.payment_processor.arn
  ]

  # Secrets to create
  secrets = {
    "database/card-vault" = {
      description     = "Card vault database credentials"
      recovery_window = 30
      enable_rotation = true
      rotation_days   = 30
    }
    "api/payment-gateway" = {
      description = "Payment gateway API credentials"
    }
    "api/card-network" = {
      description = "Visa/Mastercard network credentials"
    }
  }
}

# Attach read policy to service role
resource "aws_iam_role_policy_attachment" "tokenization_secrets" {
  role       = aws_iam_role.tokenization.name
  policy_arn = module.secrets.read_secrets_policy_arn
}
```

## PCI-DSS Compliance

| Requirement | Implementation |
|-------------|----------------|
| 3.5 - Protect encryption keys | KMS with strict IAM policy |
| 3.6 - Key management procedures | Automatic annual rotation |
| 8.2 - Proper authentication | Secrets Manager, no hardcoded credentials |