# ------------------------------------------------------------------------------
# SECURITY BASELINE MODULE - VARIABLES
# Centralized security controls for HIPAA-compliant landing zone
# ------------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "security"
}

# ------------------------------------------------------------------------------
# CLOUDTRAIL CONFIGURATION
# ------------------------------------------------------------------------------

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for API audit logging"
  type        = bool
  default     = true
}

variable "cloudtrail_s3_bucket_name" {
  description = "Name of S3 bucket for CloudTrail logs (created by this module)"
  type        = string
}

variable "cloudtrail_retention_days" {
  description = "Days to retain CloudTrail logs in S3 (HIPAA requires 6 years minimum for some records)"
  type        = number
  default     = 2555  # ~7 years
}

variable "enable_cloudtrail_log_file_validation" {
  description = "Enable log file integrity validation"
  type        = bool
  default     = true  # Required for HIPAA - proves logs weren't tampered
}

# ------------------------------------------------------------------------------
# GUARDDUTY CONFIGURATION
# ------------------------------------------------------------------------------

variable "enable_guardduty" {
  description = "Enable GuardDuty threat detection"
  type        = bool
  default     = true
}

variable "guardduty_finding_publishing_frequency" {
  description = "Frequency of GuardDuty finding exports (FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS)"
  type        = string
  default     = "FIFTEEN_MINUTES"  # Fast detection for healthcare
}

# ------------------------------------------------------------------------------
# AWS CONFIG CONFIGURATION
# ------------------------------------------------------------------------------

variable "enable_config" {
  description = "Enable AWS Config for configuration compliance"
  type        = bool
  default     = true
}

variable "config_s3_bucket_name" {
  description = "Name of S3 bucket for Config snapshots"
  type        = string
}

variable "config_retention_days" {
  description = "Days to retain Config snapshots"
  type        = number
  default     = 2555  # Match CloudTrail
}

# ------------------------------------------------------------------------------
# SECURITY HUB CONFIGURATION
# ------------------------------------------------------------------------------

variable "enable_security_hub" {
  description = "Enable Security Hub for centralized findings"
  type        = bool
  default     = true
}

variable "security_hub_standards" {
  description = "Security standards to enable in Security Hub"
  type        = list(string)
  default = [
    "aws-foundational-security-best-practices/v/1.0.0",
    "cis-aws-foundations-benchmark/v/1.4.0",
    "nist-800-53/v/5.0.0"
  ]
}

# ------------------------------------------------------------------------------
# COMMON
# ------------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}