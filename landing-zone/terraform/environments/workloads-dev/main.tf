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

  # Remote state configuration
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
# VPC
# Development VPC with cost optimization (single NAT)
# ------------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  name        = "dev"
  cidr_block  = "10.10.0.0/16"  # Different CIDR than prod
  environment = "development"

  # Cost optimization: single NAT Gateway
  enable_nat_gateway = true
  single_nat_gateway = true  # Save ~$32/month, acceptable for dev

  # Shorter retention for dev (still need some logs for debugging)
  enable_flow_logs        = true
  flow_log_retention_days = 30  # 30 days sufficient for dev

  tags = {
    DataClassification = "internal"  # No real PHI in dev
    Compliance         = "none"
  }
}

# ------------------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "Development VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for application deployment"
  value       = module.vpc.private_subnet_ids
}

output "data_subnet_ids" {
  description = "Data subnet IDs for RDS deployment"
  value       = module.vpc.data_subnet_ids
}