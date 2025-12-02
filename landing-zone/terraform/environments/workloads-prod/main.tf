# ------------------------------------------------------------------------------
# WORKLOADS-PROD ENVIRONMENT
# Production environment for MedFlow healthcare applications
# HIPAA-compliant configuration with high availability
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
  #   key            = "workloads-prod/terraform.tfstate"
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
      Environment = "production"
      Project     = "medflow"
      ManagedBy   = "terraform"
      CostCenter  = "engineering"
      Compliance  = "hipaa"
    }
  }
}

# ------------------------------------------------------------------------------
# DATA SOURCES
# In production, these would reference the actual Transit Gateway via RAM share
# For now, we use variables to demonstrate the pattern
# ------------------------------------------------------------------------------

# When Transit Gateway is shared via RAM, uncomment:
# data "aws_ec2_transit_gateway" "main" {
#   filter {
#     name   = "owner-id"
#     values = [var.shared_services_account_id]
#   }
# }

# ------------------------------------------------------------------------------
# PRODUCTION VPC
# High availability configuration with multi-AZ NAT
# ------------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  name        = "prod"
  cidr_block  = "10.20.0.0/16"
  environment = "production"

  # Production: Multi-AZ NAT for high availability
  # Note: If using centralized NAT in shared-services, set this to false
  enable_nat_gateway = true
  single_nat_gateway = false

  # HIPAA requirement: full logging
  enable_flow_logs        = true
  flow_log_retention_days = 365

  tags = {
    DataClassification = "phi"
  }
}

# ------------------------------------------------------------------------------
# TRANSIT GATEWAY ATTACHMENT
# Connects prod VPC to the central Transit Gateway
# Uncomment when Transit Gateway is available via RAM share
# ------------------------------------------------------------------------------

# module "tgw_attachment" {
#   source = "../../modules/tgw-attachment"
#
#   name                           = "prod"
#   vpc_id                         = module.vpc.vpc_id
#   subnet_ids                     = module.vpc.private_subnet_ids
#   transit_gateway_id             = var.transit_gateway_id
#   transit_gateway_route_table_id = var.transit_gateway_prod_route_table_id
#
#   vpc_route_table_ids = concat(
#     module.vpc.private_route_table_ids,
#     [module.vpc.data_route_table_id]
#   )
#
#   # Routes to other VPCs via Transit Gateway
#   destination_cidr_blocks = [
#     "10.0.0.0/16",   # Security VPC
#     "10.1.0.0/16",   # Shared Services VPC
#   ]
#   # Note: No route to 10.10.0.0/16 (Dev) - isolation enforced
# }

# ------------------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "Production VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "Production VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs for application deployment"
  value       = module.vpc.private_subnet_ids
}

output "data_subnet_ids" {
  description = "Data subnet IDs for RDS deployment"
  value       = module.vpc.data_subnet_ids
}

output "nat_gateway_ips" {
  description = "NAT Gateway public IPs"
  value       = module.vpc.nat_gateway_public_ips
}