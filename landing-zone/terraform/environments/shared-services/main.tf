# ------------------------------------------------------------------------------
# SHARED SERVICES ACCOUNT ENVIRONMENT
# Central networking hub for MedFlow landing zone
#
# This account hosts:
#   - Transit Gateway (network hub connecting all VPCs)
#   - Centralized NAT Gateway (egress for all accounts)
#   - DNS infrastructure (Route 53 private hosted zones)
#   - CI/CD runners (future)
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }

  # Remote state - uncomment when S3 backend is ready
  # backend "s3" {
  #   bucket         = "medflow-terraform-state"
  #   key            = "shared-services/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# ------------------------------------------------------------------------------
# PROVIDER CONFIGURATION
# ------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "shared-services"
      Project     = "medflow"
      ManagedBy   = "terraform"
    }
  }
}

# ------------------------------------------------------------------------------
# SHARED SERVICES VPC
# Hosts Transit Gateway attachments, NAT Gateways, and shared infrastructure
# ------------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  name        = "shared"
  cidr_block  = "10.1.0.0/16"
  environment = "shared-services"

  # This VPC provides centralized NAT for all accounts
  enable_nat_gateway = true
  single_nat_gateway = false  # Multi-AZ for high availability

  enable_flow_logs        = true
  flow_log_retention_days = 365

  tags = {
    Purpose = "network-hub"
  }
}

# ------------------------------------------------------------------------------
# TRANSIT GATEWAY
# Central hub connecting all VPCs across accounts
# ------------------------------------------------------------------------------

module "transit_gateway" {
  source = "../../modules/transit-gateway"

  name        = "medflow"
  environment = "shared-services"

  # Security: require manual approval for cross-account attachments
  enable_auto_accept_shared_attachments = false

  tags = {
    Purpose = "network-hub"
  }
}

# ------------------------------------------------------------------------------
# TRANSIT GATEWAY ATTACHMENT - SHARED SERVICES VPC
# Connect this VPC to the Transit Gateway
# ------------------------------------------------------------------------------

module "tgw_attachment" {
  source = "../../modules/tgw-attachment"

  name                           = "shared"
  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnet_ids
  transit_gateway_id             = module.transit_gateway.transit_gateway_id
  transit_gateway_route_table_id = module.transit_gateway.shared_route_table_id

  # Routes from Shared Services VPC to other VPCs
  vpc_route_table_ids = concat(
    module.vpc.private_route_table_ids,
    [module.vpc.data_route_table_id]
  )

  # CIDRs of other VPCs (Shared Services needs to reach all)
  destination_cidr_blocks = [
    "10.0.0.0/16",   # Security VPC
    "10.10.0.0/16",  # Workloads Dev VPC
    "10.20.0.0/16",  # Workloads Prod VPC
  ]

  tags = {
    Purpose = "network-hub"
  }
}

# ------------------------------------------------------------------------------
# OUTPUTS
# Values needed by other accounts to connect to Transit Gateway
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "Shared Services VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "Shared Services VPC CIDR"
  value       = module.vpc.vpc_cidr_block
}

output "transit_gateway_id" {
  description = "Transit Gateway ID - share this with other accounts"
  value       = module.transit_gateway.transit_gateway_id
}

output "transit_gateway_route_tables" {
  description = "Transit Gateway route table IDs by environment"
  value       = module.transit_gateway.route_table_ids
}

output "ram_share_arn" {
  description = "RAM share ARN for cross-account TGW access"
  value       = module.transit_gateway.ram_share_arn
}

output "nat_gateway_ips" {
  description = "NAT Gateway public IPs (for firewall whitelisting)"
  value       = module.vpc.nat_gateway_public_ips
}