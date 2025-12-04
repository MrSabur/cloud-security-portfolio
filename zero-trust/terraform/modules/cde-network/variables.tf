# ------------------------------------------------------------------------------
# CDE NETWORK MODULE - VARIABLES
# Isolated network for Cardholder Data Environment (PCI Scope)
# ------------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to create CDE subnets in"
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block (for security group rules)"
  type        = string
}

variable "cde_cidr_blocks" {
  description = "CIDR blocks for CDE subnets (one per AZ)"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones for CDE subnets"
  type        = list(string)
}

variable "application_security_group_id" {
  description = "Security group ID of application tier (allowed to reach tokenization service)"
  type        = string
}

variable "application_subnet_cidr_blocks" {
  description = "CIDR blocks of application subnets (for NACL rules)"
  type        = list(string)
}

# ------------------------------------------------------------------------------
# VPC ENDPOINTS
# ------------------------------------------------------------------------------

variable "enable_vpc_endpoints" {
  description = "Create VPC endpoints for CDE (required for no-internet architecture)"
  type        = bool
  default     = true
}

variable "endpoints_subnet_cidr_blocks" {
  description = "CIDR blocks for VPC endpoint subnets"
  type        = list(string)
  default     = []
}

# ------------------------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------------------------

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs for CDE subnets"
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Days to retain flow logs"
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
