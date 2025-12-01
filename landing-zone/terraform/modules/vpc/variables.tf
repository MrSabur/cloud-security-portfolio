# ------------------------------------------------------------------------------
# REQUIRED VARIABLES
# These must be provided when calling the module
# ------------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for all resources (e.g., 'prod', 'dev')"
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 20
    error_message = "Name must be between 1 and 20 characters."
  }
}

variable "cidr_block" {
  description = "CIDR block for the VPC (e.g., '10.20.0.0/16')"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "environment" {
  description = "Environment name (e.g., 'production', 'development')"
  type        = string

  validation {
    condition     = contains(["production", "development", "staging", "security", "shared-services"], var.environment)
    error_message = "Environment must be one of: production, development, staging, security, shared-services."
  }
}

# ------------------------------------------------------------------------------
# OPTIONAL VARIABLES
# These have sensible defaults but can be overridden
# ------------------------------------------------------------------------------

variable "availability_zones" {
  description = "List of availability zones to use (defaults to first 2 in region)"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateway(s) for private subnet internet access"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ (cost savings for non-prod)"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Number of days to retain flow logs in CloudWatch"
  type        = number
  default     = 365  # HIPAA requires minimum 6 years for some records; 365 is a baseline
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}