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

  # Remote state configuration
  # In production, uncomment this to store state in S3
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
    }
  }
}

# ------------------------------------------------------------------------------
# VPC
# Production VPC with high availability (multi-AZ NAT)
# ------------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  name        = "prod"
  cidr_block  = "10.20.0.0/16"
  environment = "production"

  # Production settings: HA NAT Gateway (one per AZ)
  enable_nat_gateway = true
  single_nat_gateway = false  # One NAT per AZ for high availability

  # HIPAA requirement: retain flow logs
  enable_flow_logs        = true
  flow_log_retention_days = 365

  tags = {
    DataClassification = "phi"  # Contains Protected Health Information
    Compliance         = "hipaa"
  }
}

# ------------------------------------------------------------------------------
# OUTPUTS
# Values needed by other configurations and for reference
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "Production VPC ID"
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

output "nat_gateway_ips" {
  description = "NAT Gateway public IPs (for whitelisting with external services)"
  value       = module.vpc.nat_gateway_public_ips
}