variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# KMS Configuration
################################################################################

variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30
}

################################################################################
# S3 Configuration
################################################################################

variable "access_logging_bucket" {
  description = "S3 bucket for access logging (optional)"
  type        = string
  default     = null
}

################################################################################
# Bedrock Guardrail Configuration
################################################################################

variable "phi_filter_action" {
  description = "Action for PHI filters: BLOCK or ANONYMIZE"
  type        = string
  default     = "ANONYMIZE"

  validation {
    condition     = contains(["BLOCK", "ANONYMIZE"], var.phi_filter_action)
    error_message = "phi_filter_action must be BLOCK or ANONYMIZE"
  }
}

variable "mrn_regex_pattern" {
  description = "Regex pattern for Medical Record Number (organization-specific)"
  type        = string
  default     = null
}

variable "blocked_words" {
  description = "List of words to block in AI responses"
  type        = list(string)
  default     = []
}

################################################################################
# CloudWatch Configuration
################################################################################

variable "log_retention_days" {
  description = "CloudWatch log retention in days (HIPAA: minimum 2555 for 7 years)"
  type        = number
  default     = 2555

  validation {
    condition     = var.log_retention_days >= 2555
    error_message = "Log retention must be at least 2555 days (7 years) for HIPAA compliance"
  }
}

variable "phi_leakage_alarm_threshold" {
  description = "Number of PHI leakage attempts before alarming"
  type        = number
  default     = 5
}

variable "prompt_injection_alarm_threshold" {
  description = "Number of prompt injection attempts before alarming"
  type        = number
  default     = 10
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = null
}

################################################################################
# Model Access Configuration
################################################################################

variable "allowed_model_arns_tier1" {
  description = "Bedrock model ARNs allowed for Tier 1 (Standard) AI"
  type        = list(string)
  default     = ["arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku-*"]
}

variable "allowed_model_arns_tier2" {
  description = "Bedrock model ARNs allowed for Tier 2 (Elevated) AI"
  type        = list(string)
  default     = [
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku-*",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-sonnet-*"
  ]
}

variable "allowed_model_arns_tier3" {
  description = "Bedrock model ARNs allowed for Tier 3 (Critical) AI"
  type        = list(string)
  default     = [
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku-*",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-sonnet-*",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-opus-*"
  ]
}

################################################################################
# Macie Configuration
################################################################################

variable "enable_macie" {
  description = "Enable Macie for PHI discovery scanning"
  type        = bool
  default     = false
}
