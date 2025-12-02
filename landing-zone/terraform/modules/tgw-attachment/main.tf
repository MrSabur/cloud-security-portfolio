# ------------------------------------------------------------------------------
# TRANSIT GATEWAY VPC ATTACHMENT
# Connects a VPC to the Transit Gateway and configures routing
#
# This module:
#   1. Creates the TGW attachment in the specified subnets
#   2. Associates the attachment with the specified TGW route table
#   3. Propagates the VPC's routes to the TGW route table
#   4. Adds routes in the VPC's route tables pointing to the TGW
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
      ManagedBy = "terraform"
      Module    = "tgw-attachment"
    },
    var.tags
  )
}

# ------------------------------------------------------------------------------
# TRANSIT GATEWAY VPC ATTACHMENT
# Creates the connection between the VPC and Transit Gateway
# ------------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids

  # Configuration options
  dns_support                                     = var.dns_support ? "enable" : "disable"
  appliance_mode_support                          = var.appliance_mode_support ? "enable" : "disable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(local.common_tags, {
    Name = "${var.name}-tgw-attachment"
  })
}

# ------------------------------------------------------------------------------
# ROUTE TABLE ASSOCIATION
# Associates the attachment with the specified TGW route table
# This determines which route table governs traffic FROM this VPC
# ------------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id
}

# ------------------------------------------------------------------------------
# ROUTE TABLE PROPAGATION
# Propagates this VPC's CIDR to the TGW route table
# This allows other VPCs using this route table to reach this VPC
# ------------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id
}

# ------------------------------------------------------------------------------
# VPC ROUTE TABLE ROUTES
# Adds routes in the VPC pointing to the Transit Gateway
# This allows traffic FROM the VPC to reach other VPCs via TGW
# ------------------------------------------------------------------------------

resource "aws_route" "to_transit_gateway" {
  count = length(var.vpc_route_table_ids) * length(var.destination_cidr_blocks)

  route_table_id         = var.vpc_route_table_ids[floor(count.index / length(var.destination_cidr_blocks))]
  destination_cidr_block = var.destination_cidr_blocks[count.index % length(var.destination_cidr_blocks)]
  transit_gateway_id     = var.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}