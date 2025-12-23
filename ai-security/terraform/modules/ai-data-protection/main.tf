################################################################################
# AI Data Protection Module
# Implements Layer 1-5 controls from ADR-002
################################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

################################################################################
# Layer 1: KMS Key for AI Data Encryption
################################################################################

resource "aws_kms_key" "ai_data" {
  description             = "KMS key for AI data encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Bedrock Service"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "ai_data" {
  name          = "alias/${local.name_prefix}-ai-data"
  target_key_id = aws_kms_key.ai_data.key_id
}

################################################################################
# Layer 1: S3 Bucket for AI Training Data (Tiered Access)
################################################################################

resource "aws_s3_bucket" "ai_data" {
  bucket = "${local.name_prefix}-ai-data-${data.aws_caller_identity.current.account_id}"

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "ai_data" {
  bucket = aws_s3_bucket.ai_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ai_data" {
  bucket = aws_s3_bucket.ai_data.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.ai_data.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "ai_data" {
  bucket = aws_s3_bucket.ai_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "ai_data" {
  count = var.access_logging_bucket != null ? 1 : 0

  bucket        = aws_s3_bucket.ai_data.id
  target_bucket = var.access_logging_bucket
  target_prefix = "ai-data-access-logs/"
}

# Create folder structure for tiered data access
resource "aws_s3_object" "tier_folders" {
  for_each = toset([
    "public/training/synthetic/",
    "internal/policies/",
    "internal/de-identified/",
    "phi/training/approved-datasets/",
    "phi/rag/patient-records/",
    "restricted/research/"
  ])

  bucket  = aws_s3_bucket.ai_data.id
  key     = each.value
  content = ""
}

################################################################################
# Layer 2: Bedrock Guardrail for PHI Protection
################################################################################

resource "aws_bedrock_guardrail" "phi_protection" {
  name                      = "${local.name_prefix}-phi-protection"
  description               = "Guardrail for PHI protection in AI inference"
  blocked_input_messaging   = "Your input contains sensitive information that cannot be processed."
  blocked_outputs_messaging = "The response was blocked due to sensitive content."

  # Content filters
  content_policy_config {
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
  }

  # Sensitive information filters (PII/PHI)
  sensitive_information_policy_config {
    pii_entities_config {
      type   = "US_SOCIAL_SECURITY_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "CREDIT_DEBIT_CARD_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "EMAIL"
      action = var.phi_filter_action
    }
    pii_entities_config {
      type   = "PHONE"
      action = var.phi_filter_action
    }
    pii_entities_config {
      type   = "NAME"
      action = var.phi_filter_action
    }
    pii_entities_config {
      type   = "US_INDIVIDUAL_TAX_IDENTIFICATION_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "US_BANK_ACCOUNT_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "US_PASSPORT_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "DRIVER_ID"
      action = var.phi_filter_action
    }

    # Custom regex for MRN pattern
    dynamic "regexes_config" {
      for_each = var.mrn_regex_pattern != null ? [1] : []
      content {
        name        = "medical_record_number"
        description = "Organization-specific MRN pattern"
        pattern     = var.mrn_regex_pattern
        action      = "BLOCK"
      }
    }
  }

  # Topic filters for healthcare
  topic_policy_config {
    topics_config {
      name       = "medical_advice_without_review"
      definition = "Direct medical advice, diagnoses, or treatment recommendations without physician review"
      examples   = ["You should take this medication", "Based on your symptoms, you have"]
      type       = "DENY"
    }
    topics_config {
      name       = "prescription_recommendations"
      definition = "Specific medication dosages or prescription recommendations"
      examples   = ["Take 500mg of", "I recommend you start taking"]
      type       = "DENY"
    }
  }

  # Word filters
  word_policy_config {
    managed_word_lists_config {
      type = "PROFANITY"
    }
    dynamic "words_config" {
      for_each = var.blocked_words
      content {
        text = words_config.value
      }
    }
  }

  kms_key_arn = aws_kms_key.ai_data.arn

  tags = var.tags
}

resource "aws_bedrock_guardrail_version" "phi_protection" {
  guardrail_arn = aws_bedrock_guardrail.phi_protection.guardrail_arn
  description   = "Initial version"
}

################################################################################
# Layer 5: CloudWatch Log Group for AI Audit Trail
################################################################################

resource "aws_cloudwatch_log_group" "ai_audit" {
  name              = "/ai/${local.name_prefix}/inference-audit"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.ai_data.arn

  tags = var.tags
}

# Metric filter for PHI leakage detection
resource "aws_cloudwatch_log_metric_filter" "phi_leakage" {
  name           = "${local.name_prefix}-phi-leakage"
  pattern        = "{ $.guardrail_action = \"BLOCKED\" && $.filter_type = \"PII\" }"
  log_group_name = aws_cloudwatch_log_group.ai_audit.name

  metric_transformation {
    name          = "PHILeakageAttempts"
    namespace     = "${var.project_name}/AI/Security"
    value         = "1"
    default_value = "0"
  }
}

# Metric filter for prompt injection attempts
resource "aws_cloudwatch_log_metric_filter" "prompt_injection" {
  name           = "${local.name_prefix}-prompt-injection"
  pattern        = "{ $.guardrail_action = \"BLOCKED\" && $.filter_type = \"TOPIC\" }"
  log_group_name = aws_cloudwatch_log_group.ai_audit.name

  metric_transformation {
    name          = "PromptInjectionAttempts"
    namespace     = "${var.project_name}/AI/Security"
    value         = "1"
    default_value = "0"
  }
}

################################################################################
# Layer 5: CloudWatch Alarms
################################################################################

resource "aws_cloudwatch_metric_alarm" "phi_leakage" {
  alarm_name          = "${local.name_prefix}-phi-leakage-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "PHILeakageAttempts"
  namespace           = "${var.project_name}/AI/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = var.phi_leakage_alarm_threshold
  alarm_description   = "PHI leakage attempts detected in AI inference"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "prompt_injection" {
  alarm_name          = "${local.name_prefix}-prompt-injection-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "PromptInjectionAttempts"
  namespace           = "${var.project_name}/AI/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = var.prompt_injection_alarm_threshold
  alarm_description   = "Prompt injection attempts detected"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  tags = var.tags
}

################################################################################
# Layer 1: IAM Roles for Tiered AI Access
################################################################################

# Tier 1: Standard AI (public/synthetic data only)
resource "aws_iam_role" "ai_tier1" {
  name = "${local.name_prefix}-ai-tier1-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "ai_tier1" {
  name = "${local.name_prefix}-ai-tier1-policy"
  role = aws_iam_role.ai_tier1.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3PublicDataAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.ai_data.arn,
          "${aws_s3_bucket.ai_data.arn}/public/*"
        ]
      },
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = var.allowed_model_arns_tier1
      },
      {
        Sid    = "GuardrailRequired"
        Effect = "Allow"
        Action = [
          "bedrock:ApplyGuardrail"
        ]
        Resource = aws_bedrock_guardrail.phi_protection.guardrail_arn
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.ai_data.arn
      }
    ]
  })
}

# Tier 2: Elevated AI (de-identified data)
resource "aws_iam_role" "ai_tier2" {
  name = "${local.name_prefix}-ai-tier2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "ai_tier2" {
  name = "${local.name_prefix}-ai-tier2-policy"
  role = aws_iam_role.ai_tier2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3DeidentifiedAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.ai_data.arn,
          "${aws_s3_bucket.ai_data.arn}/public/*",
          "${aws_s3_bucket.ai_data.arn}/internal/*"
        ]
      },
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = var.allowed_model_arns_tier2
      },
      {
        Sid    = "GuardrailRequired"
        Effect = "Allow"
        Action = [
          "bedrock:ApplyGuardrail"
        ]
        Resource = aws_bedrock_guardrail.phi_protection.guardrail_arn
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.ai_data.arn
      }
    ]
  })
}

# Tier 3: Critical AI (PHI access with full controls)
resource "aws_iam_role" "ai_tier3" {
  name = "${local.name_prefix}-ai-tier3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "ai_tier3" {
  name = "${local.name_prefix}-ai-tier3-policy"
  role = aws_iam_role.ai_tier3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3PHIAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.ai_data.arn,
          "${aws_s3_bucket.ai_data.arn}/public/*",
          "${aws_s3_bucket.ai_data.arn}/internal/*",
          "${aws_s3_bucket.ai_data.arn}/phi/*"
        ]
      },
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = var.allowed_model_arns_tier3
      },
      {
        Sid    = "GuardrailRequired"
        Effect = "Allow"
        Action = [
          "bedrock:ApplyGuardrail"
        ]
        Resource = aws_bedrock_guardrail.phi_protection.guardrail_arn
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.ai_data.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.ai_audit.arn}:*"
      }
    ]
  })
}

################################################################################
# Optional: Macie for PHI Discovery
################################################################################

resource "aws_macie2_account" "this" {
  count = var.enable_macie ? 1 : 0

  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

resource "aws_macie2_classification_job" "ai_data" {
  count = var.enable_macie ? 1 : 0

  name     = "${local.name_prefix}-ai-data-scan"
  job_type = "SCHEDULED"

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [aws_s3_bucket.ai_data.id]
    }
    scoping {
      includes {
        and {
          simple_scope_term {
            comparator = "STARTS_WITH"
            key        = "OBJECT_KEY"
            values     = ["phi/", "internal/"]
          }
        }
      }
    }
  }

  schedule_frequency {
    weekly_schedule = "MONDAY"
  }

  sampling_percentage = 100

  tags = var.tags

  depends_on = [aws_macie2_account.this]
}

################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
