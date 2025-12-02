# ------------------------------------------------------------------------------
# TRANSIT GATEWAY ATTACHMENT - VARIABLES
# Connects a VPC to the Transit Gateway hub
# ------------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for the attachment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to attach"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the attachment (one per AZ, typically private subnets)"
  type        = list(string)
}

variable "transit_gateway_id" {
  description = "ID of the Transit Gateway to attach to"
  type        = string
}

variable "transit_gateway_route_table_id" {
  description = "ID of the Transit Gateway route table to associate with"
  type        = string
}

variable "vpc_route_table_ids" {
  description = "List of VPC route table IDs that need routes to the Transit Gateway"
  type        = list(string)
}

variable "destination_cidr_blocks" {
  description = "List of CIDR blocks to route through the Transit Gateway (e.g., other VPC CIDRs)"
  type        = list(string)
  default     = []
}

variable "appliance_mode_support" {
  description = "Enable appliance mode for stateful inspection (e.g., firewalls)"
  type        = bool
  default     = false
}

variable "dns_support" {
  description = "Enable DNS support for the attachment"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}