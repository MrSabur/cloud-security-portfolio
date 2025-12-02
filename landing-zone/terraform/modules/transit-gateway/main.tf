# ------------------------------------------------------------------------------
# TRANSIT GATEWAY MODULE
# Creates a Transit Gateway hub with isolated route tables for prod/dev separation
# 
# Architecture:
#   - Single Transit Gateway as central hub
#   - Separate route tables for production and development isolation
#   - Shared route table for security and shared-services (reachable by all)
#   - No direct route between prod and dev (hard network isolation)
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
# LOCAL VALUES
# ------------------------------------------------------------------------------

locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "transit-gateway"
      Project     = "medflow-landing-zone"
    },
    var.tags
  )
}

# ------------------------------------------------------------------------------
# TRANSIT GATEWAY
# The central hub that all VPCs connect to
# ------------------------------------------------------------------------------

resource "aws_ec2_transit_gateway" "this" {
  description = "Central hub for ${var.name} landing zone"

  amazon_side_asn                 = var.amazon_side_asn
  dns_support                     = var.enable_dns_support ? "enable" : "disable"
  vpn_ecmp_support                = var.enable_vpn_ecmp_support ? "enable" : "disable"
  auto_accept_shared_attachments  = var.enable_auto_accept_shared_attachments ? "enable" : "disable"

  # Don't use the default route table - we create explicit ones for isolation
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = merge(local.common_tags, {
    Name = "${var.name}-tgw"
  })
}

# ------------------------------------------------------------------------------
# ROUTE TABLES
# Separate route tables enable network isolation between environments
# ------------------------------------------------------------------------------

# Production route table - for prod workloads
resource "aws_ec2_transit_gateway_route_table" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(local.common_tags, {
    Name        = "${var.name}-prod-rt"
    Environment = "production"
  })
}

# Development route table - for dev/test workloads  
resource "aws_ec2_transit_gateway_route_table" "dev" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(local.common_tags, {
    Name        = "${var.name}-dev-rt"
    Environment = "development"
  })
}

# Shared route table - for security and shared-services VPCs
# These need to be reachable from both prod and dev
resource "aws_ec2_transit_gateway_route_table" "shared" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(local.common_tags, {
    Name        = "${var.name}-shared-rt"
    Environment = "shared"
  })
}

# ------------------------------------------------------------------------------
# RESOURCE ACCESS MANAGER SHARE (for cross-account attachments)
# Allows VPCs in other accounts to attach to this Transit Gateway
# ------------------------------------------------------------------------------

resource "aws_ram_resource_share" "transit_gateway" {
  name                      = "${var.name}-tgw-share"
  allow_external_principals = false  # Only share within organization

  tags = merge(local.common_tags, {
    Name = "${var.name}-tgw-share"
  })
}

resource "aws_ram_resource_association" "transit_gateway" {
  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.transit_gateway.arn
}

# Note: To share with specific accounts or OUs, add aws_ram_principal_association resources
# Example:
# resource "aws_ram_principal_association" "workloads_prod" {
#   principal          = "arn:aws:organizations::${data.aws_caller_identity.current.account_id}:ou/o-xxx/ou-xxx-xxx"
#   resource_share_arn = aws_ram_resource_share.transit_gateway.arn
# }