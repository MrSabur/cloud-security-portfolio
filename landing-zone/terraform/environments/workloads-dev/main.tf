# ------------------------------------------------------------------------------
# WORKLOADS-DEV ENVIRONMENT
# Development and testing environment for MedFlow
# Cost-optimized configuration (single NAT, shorter log retention)
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
  #   key            = "workloads-dev/terraform.tfstate"
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
      Environment = "development"
      Project     = "medflow"
      ManagedBy   = "terraform"
      CostCenter  = "engineering"
    }
  }
}

# ------------------------------------------------------------------------------
# DEVELOPMENT VPC
# Cost-optimized with single NAT Gateway
# ------------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  name        = "dev"
  cidr_block  = "10.10.0.0/16"
  environment = "development"

  # Cost optimization: single NAT Gateway
  enable_nat_gateway = true
  single_nat_gateway = true

  # Shorter retention for dev (cost savings)
  enable_flow_logs        = true
  flow_log_retention_days = 30

  tags = {
    DataClassification = "internal"
  }
}

# ------------------------------------------------------------------------------
# TRANSIT GATEWAY ATTACHMENT
# Connects dev VPC to the central Transit Gateway
# Uncomment when Transit Gateway is available via RAM share
# ------------------------------------------------------------------------------

# module "tgw_attachment" {
#   source = "../../modules/tgw-attachment"
#
#   name                           = "dev"
#   vpc_id                         = module.vpc.vpc_id
#   subnet_ids                     = module.vpc.private_subnet_ids
#   transit_gateway_id             = var.transit_gateway_id
#   transit_gateway_route_table_id = var.transit_gateway_dev_route_table_id
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
#   # Note: No route to 10.20.0.0/16 (Prod) - isolation enforced
# }

# ------------------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "Development VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "Development VPC CIDR block"
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