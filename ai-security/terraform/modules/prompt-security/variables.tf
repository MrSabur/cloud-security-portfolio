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
# WAF Configuration
################################################################################

variable "rate_limit_per_user" {
  description = "Maximum requests per 5-minute window per IP"
  type        = number
  default     = 500
}

variable "max_request_size_bytes" {
  description = "Maximum request body size in bytes"
  type        = number
  default     = 10240 # 10KB
}

################################################################################
# Guardrail Configuration
################################################################################

variable "grounding_threshold" {
  description = "Threshold for contextual grounding check (0-1)"
  type        = number
  default     = 0.7

  validation {
    condition     = var.grounding_threshold >= 0 && var.grounding_threshold <= 1
    error_message = "Grounding threshold must be between 0 and 1"
  }
}

variable "relevance_threshold" {
  description = "Threshold for relevance check (0-1)"
  type        = number
  default     = 0.7

  validation {
    condition     = var.relevance_threshold >= 0 && var.relevance_threshold <= 1
    error_message = "Relevance threshold must be between 0 and 1"
  }
}

################################################################################
# Logging Configuration
################################################################################

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 2555 # 7 years for HIPAA

  validation {
    condition     = var.log_retention_days >= 365
    error_message = "Log retention must be at least 365 days"
  }
}

################################################################################
# Alarm Configuration
################################################################################

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = null
}

variable "input_block_alarm_threshold" {
  description = "Number of input blocks in 5 min before alarming"
  type        = number
  default     = 50
}

variable "waf_block_alarm_threshold" {
  description = "Number of WAF blocks in 5 min before alarming"
  type        = number
  default     = 100
}
