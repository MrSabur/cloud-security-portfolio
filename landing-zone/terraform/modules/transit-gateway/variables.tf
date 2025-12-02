# ------------------------------------------------------------------------------
# TRANSIT GATEWAY MODULE - VARIABLES
# Hub-and-spoke network connectivity with route table isolation
# ------------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "shared"
}

variable "amazon_side_asn" {
  description = "Private ASN for the Transit Gateway (64512-65534 for 16-bit, or 4200000000-4294967294 for 32-bit)"
  type        = number
  default     = 64512
}

variable "enable_dns_support" {
  description = "Enable DNS support for VPC attachments"
  type        = bool
  default     = true
}

variable "enable_vpn_ecmp_support" {
  description = "Enable Equal Cost Multi-Path routing for VPN connections"
  type        = bool
  default     = true
}

variable "enable_auto_accept_shared_attachments" {
  description = "Auto-accept cross-account attachment requests (use with caution)"
  type        = bool
  default     = false  # Require manual approval for security
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}