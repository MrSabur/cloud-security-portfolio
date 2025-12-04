# ------------------------------------------------------------------------------
# API GATEWAY MODULE - VARIABLES
# ------------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "description" {
  description = "API description"
  type        = string
  default     = "Payment Processing API"
}

# ------------------------------------------------------------------------------
# WAF
# ------------------------------------------------------------------------------

variable "enable_waf" {
  description = "Enable AWS WAF for API protection"
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Rate limit per IP (requests per 5 minutes)"
  type        = number
  default     = 2000
}

variable "waf_block_mode" {
  description = "Block malicious requests (false = count only)"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# THROTTLING
# ------------------------------------------------------------------------------

variable "throttle_burst_limit" {
  description = "API Gateway burst limit"
  type        = number
  default     = 100
}

variable "throttle_rate_limit" {
  description = "API Gateway rate limit (requests per second)"
  type        = number
  default     = 1000
}

variable "quota_limit" {
  description = "Monthly request quota"
  type        = number
  default     = 1000000
}

# ------------------------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------------------------

variable "enable_access_logs" {
  description = "Enable API Gateway access logs"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Days to retain access logs"
  type        = number
  default     = 365
}

# ------------------------------------------------------------------------------
# TAGS
# ------------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
