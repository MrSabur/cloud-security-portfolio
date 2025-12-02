# ------------------------------------------------------------------------------
# SECURITY BASELINE MODULE
# Implements core security controls for HIPAA compliance
#
# Components:
#   - CloudTrail: API audit logging with integrity validation
#   - GuardDuty: Threat detection and anomaly monitoring
#   - AWS Config: Configuration compliance and drift detection
#   - Security Hub: Centralized security findings dashboard
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
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "security-baseline"
      Project     = "medflow-landing-zone"
      Compliance  = "hipaa"
    },
    var.tags
  )
}

# ------------------------------------------------------------------------------
# CLOUDTRAIL
# Captures all API calls for audit and forensics
# ------------------------------------------------------------------------------

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = var.cloudtrail_s3_bucket_name

  tags = merge(local.common_tags, {
    Name = var.cloudtrail_s3_bucket_name
  })
}

# Block all public access - critical for HIPAA
resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for audit trail integrity
resource "aws_s3_bucket_versioning" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with AWS managed keys
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Lifecycle policy for cost management
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    id     = "archive-old-logs"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = var.cloudtrail_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Bucket policy allowing CloudTrail to write logs
resource "aws_s3_bucket_policy" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${local.region}:${local.account_id}:trail/${var.name}-trail"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/AWSLogs/${local.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:aws:cloudtrail:${local.region}:${local.account_id}:trail/${var.name}-trail"
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.cloudtrail[0].arn,
          "${aws_s3_bucket.cloudtrail[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# The CloudTrail itself
resource "aws_cloudtrail" "main" {
  count = var.enable_cloudtrail ? 1 : 0

  name                          = "${var.name}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail[0].id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = var.enable_cloudtrail_log_file_validation

  tags = merge(local.common_tags, {
    Name = "${var.name}-trail"
  })

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# ------------------------------------------------------------------------------
# GUARDDUTY
# Threat detection using ML and threat intelligence
# ------------------------------------------------------------------------------

resource "aws_guardduty_detector" "main" {
  count = var.enable_guardduty ? 1 : 0

  enable                       = true
  finding_publishing_frequency = var.guardduty_finding_publishing_frequency

  tags = merge(local.common_tags, {
    Name = "${var.name}-guardduty"
  })
}

# Enable S3 Protection
resource "aws_guardduty_detector_feature" "s3_logs" {
  count = var.enable_guardduty ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

# Enable EKS Audit Log Monitoring
resource "aws_guardduty_detector_feature" "eks_audit_logs" {
  count = var.enable_guardduty ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

# Enable EBS Malware Protection
resource "aws_guardduty_detector_feature" "ebs_malware" {
  count = var.enable_guardduty ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "EBS_MALWARE_PROTECTION"
  status      = "ENABLED"
}

# Enable RDS Login Activity Monitoring
resource "aws_guardduty_detector_feature" "rds_login" {
  count = var.enable_guardduty ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "RDS_LOGIN_EVENTS"
  status      = "ENABLED"
}

# Enable Lambda Network Activity Monitoring
resource "aws_guardduty_detector_feature" "lambda" {
  count = var.enable_guardduty ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "LAMBDA_NETWORK_LOGS"
  status      = "ENABLED"
}

# ------------------------------------------------------------------------------
# AWS CONFIG
# Configuration recording and compliance rules
# ------------------------------------------------------------------------------

# S3 bucket for Config snapshots
resource "aws_s3_bucket" "config" {
  count = var.enable_config ? 1 : 0

  bucket = var.config_s3_bucket_name

  tags = merge(local.common_tags, {
    Name = var.config_s3_bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "config" {
  count = var.enable_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "config" {
  count = var.enable_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  count = var.enable_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "config" {
  count = var.enable_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  rule {
    id     = "archive-old-snapshots"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = var.config_retention_days
    }
  }
}

resource "aws_s3_bucket_policy" "config" {
  count = var.enable_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config[0].arn}/AWSLogs/${local.account_id}/Config/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.config[0].arn,
          "${aws_s3_bucket.config[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# IAM role for AWS Config
resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0

  name = "${var.name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "config" {
  count = var.enable_config ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  count = var.enable_config ? 1 : 0

  name = "${var.name}-config-s3-policy"
  role = aws_iam_role.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:PutObjectAcl"]
        Resource = "${aws_s3_bucket.config[0].arn}/AWSLogs/${local.account_id}/Config/*"
        Condition = {
          StringLike = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config[0].arn
      }
    ]
  })
}

# Config Recorder
resource "aws_config_configuration_recorder" "main" {
  count = var.enable_config ? 1 : 0

  name     = "${var.name}-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# Config Delivery Channel
resource "aws_config_delivery_channel" "main" {
  count = var.enable_config ? 1 : 0

  name           = "${var.name}-delivery"
  s3_bucket_name = aws_s3_bucket.config[0].id

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Start the recorder
resource "aws_config_configuration_recorder_status" "main" {
  count = var.enable_config ? 1 : 0

  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# ------------------------------------------------------------------------------
# AWS CONFIG RULES
# Compliance rules for HIPAA requirements
# ------------------------------------------------------------------------------

# Rule: S3 buckets must block public access
resource "aws_config_config_rule" "s3_public_access_block" {
  count = var.enable_config ? 1 : 0

  name        = "s3-bucket-public-access-prohibited"
  description = "Checks that S3 buckets block public access (HIPAA requirement)"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: S3 buckets must have encryption enabled
resource "aws_config_config_rule" "s3_encryption" {
  count = var.enable_config ? 1 : 0

  name        = "s3-bucket-server-side-encryption-enabled"
  description = "Checks that S3 buckets have encryption enabled (HIPAA data-at-rest)"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: EBS volumes must be encrypted
resource "aws_config_config_rule" "ebs_encryption" {
  count = var.enable_config ? 1 : 0

  name        = "encrypted-volumes"
  description = "Checks that EBS volumes are encrypted (HIPAA data-at-rest)"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: RDS instances must be encrypted
resource "aws_config_config_rule" "rds_encryption" {
  count = var.enable_config ? 1 : 0

  name        = "rds-storage-encrypted"
  description = "Checks that RDS instances have encryption enabled (HIPAA data-at-rest)"

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: RDS instances must not be public
resource "aws_config_config_rule" "rds_public_access" {
  count = var.enable_config ? 1 : 0

  name        = "rds-instance-public-access-check"
  description = "Checks that RDS instances are not publicly accessible"

  source {
    owner             = "AWS"
    source_identifier = "RDS_INSTANCE_PUBLIC_ACCESS_CHECK"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: Root account must have MFA
resource "aws_config_config_rule" "root_mfa" {
  count = var.enable_config ? 1 : 0

  name        = "root-account-mfa-enabled"
  description = "Checks that root account has MFA enabled (identity security)"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: IAM users must have MFA
resource "aws_config_config_rule" "iam_user_mfa" {
  count = var.enable_config ? 1 : 0

  name        = "iam-user-mfa-enabled"
  description = "Checks that IAM users have MFA enabled"

  source {
    owner             = "AWS"
    source_identifier = "IAM_USER_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: VPC Flow Logs must be enabled
resource "aws_config_config_rule" "vpc_flow_logs" {
  count = var.enable_config ? 1 : 0

  name        = "vpc-flow-logs-enabled"
  description = "Checks that VPC Flow Logs are enabled (HIPAA audit requirement)"

  source {
    owner             = "AWS"
    source_identifier = "VPC_FLOW_LOGS_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

# ------------------------------------------------------------------------------
# SECURITY HUB
# Centralized security findings and compliance dashboard
# ------------------------------------------------------------------------------

resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub ? 1 : 0

  enable_default_standards = false
  auto_enable_controls     = true

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Enable security standards
resource "aws_securityhub_standards_subscription" "standards" {
  count = var.enable_security_hub ? length(var.security_hub_standards) : 0

  standards_arn = "arn:aws:securityhub:${local.region}::standards/${var.security_hub_standards[count.index]}"

  depends_on = [aws_securityhub_account.main]
}

# Enable GuardDuty integration with Security Hub
resource "aws_securityhub_product_subscription" "guardduty" {
  count = var.enable_security_hub && var.enable_guardduty ? 1 : 0

  product_arn = "arn:aws:securityhub:${local.region}::product/aws/guardduty"

  depends_on = [aws_securityhub_account.main]
}