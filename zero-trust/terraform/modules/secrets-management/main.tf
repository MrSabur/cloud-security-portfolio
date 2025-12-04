# ------------------------------------------------------------------------------
# SECRETS MANAGEMENT MODULE
# Centralized secrets management with KMS encryption and rotation
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# ------------------------------------------------------------------------------
# DATA SOURCES
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ------------------------------------------------------------------------------
# LOCAL VALUES
# ------------------------------------------------------------------------------

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = merge(
    {
      Module      = "secrets-management"
      Environment = var.environment
      Compliance  = "pci-dss"
    },
    var.tags
  )
}

# ------------------------------------------------------------------------------
# KMS KEY
# Customer managed key for encrypting secrets
# ------------------------------------------------------------------------------

resource "aws_kms_key" "secrets" {
  count = var.create_kms_key ? 1 : 0

  description             = "KMS key for ${var.name} secrets encryption"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.enable_key_rotation
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowKeyAdministration"
        Effect = "Allow"
        Principal = {
          AWS = length(var.key_admin_role_arns) > 0 ? var.key_admin_role_arns : ["arn:aws:iam::${local.account_id}:root"]
        }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:TagResource",
          "kms:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowKeyUsage"
        Effect = "Allow"
        Principal = {
          AWS = length(var.key_user_role_arns) > 0 ? var.key_user_role_arns : ["arn:aws:iam::${local.account_id}:root"]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsManagerAccess"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = local.account_id
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.name}-secrets-key"
  })
}

resource "aws_kms_alias" "secrets" {
  count = var.create_kms_key ? 1 : 0

  name          = "alias/${var.name}-secrets"
  target_key_id = aws_kms_key.secrets[0].key_id
}

# ------------------------------------------------------------------------------
# SECRETS
# ------------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "main" {
  for_each = var.secrets

  name        = "${var.name}/${each.key}"
  description = each.value.description
  kms_key_id  = var.create_kms_key ? aws_kms_key.secrets[0].arn : null

  recovery_window_in_days = each.value.recovery_window

  tags = merge(local.common_tags, {
    Name   = "${var.name}/${each.key}"
    Secret = each.key
  })
}

# Rotation configuration (if enabled)
resource "aws_secretsmanager_secret_rotation" "main" {
  for_each = { for k, v in var.secrets : k => v if v.enable_rotation && v.rotation_lambda_arn != null }

  secret_id           = aws_secretsmanager_secret.main[each.key].id
  rotation_lambda_arn = each.value.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = each.value.rotation_days
  }
}

# ------------------------------------------------------------------------------
# IAM POLICY FOR SECRET ACCESS
# Attach this to roles that need to read secrets
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "read_secrets" {
  name        = "${var.name}-read-secrets"
  description = "Policy to read secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetSecretValue"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          for secret in aws_secretsmanager_secret.main : secret.arn
        ]
      },
      {
        Sid    = "DecryptSecret"
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.create_kms_key ? [aws_kms_key.secrets[0].arn] : []
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${local.region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}
