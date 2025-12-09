# ------------------------------------------------------------------------------
# NOVAPAY PRODUCTION ENVIRONMENT
# Zero-Trust Payment Processing Architecture
#
# This configuration assembles all modules into a complete, PCI-DSS compliant
# payment processing infrastructure.
#
# Architecture:
#   Internet → WAF → API Gateway → Application Tier → CDE (Tokenization)
#
# PCI Scope:
#   - CDE subnets: tokenization, payment processor, card vault
#   - Everything else is out of scope (only handles tokens)
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }

  # Remote state configuration - uncomment for production
  # backend "s3" {
  #   bucket         = "novapay-terraform-state"
  #   key            = "prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "NovaPay"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "github.com/MrSabur/cloud-security-portfolio"
    }
  }
}

# ------------------------------------------------------------------------------
# DATA SOURCES
# ------------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# LOCAL VALUES
# ------------------------------------------------------------------------------

locals {
  name = "novapay"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  # CIDR allocation
  vpc_cidr            = "10.0.0.0/16"
  public_subnets      = ["10.0.0.0/24", "10.0.1.0/24"]
  application_subnets = ["10.0.10.0/24", "10.0.11.0/24"]
  cde_subnets         = ["10.0.100.0/24", "10.0.101.0/24"]

  common_tags = {
    Project     = "NovaPay"
    Environment = var.environment
    Compliance  = "pci-dss"
  }
}

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${local.name}-igw" })
}

# ------------------------------------------------------------------------------
# PUBLIC SUBNETS (ALB, NAT)
# ------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count                   = length(local.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name}-public-${local.azs[count.index]}"
    Tier = "public"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${local.name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway for application tier outbound
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${local.name}-nat-eip" })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(local.common_tags, { Name = "${local.name}-nat" })

  depends_on = [aws_internet_gateway.main]
}

# ------------------------------------------------------------------------------
# APPLICATION SUBNETS (out of PCI scope - tokens only)
# ------------------------------------------------------------------------------

resource "aws_subnet" "application" {
  count                   = length(local.application_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.application_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name      = "${local.name}-app-${local.azs[count.index]}"
    Tier      = "application"
    PCI_Scope = "false"
  })
}

resource "aws_route_table" "application" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${local.name}-app-rt" })
}

resource "aws_route_table_association" "application" {
  count          = length(aws_subnet.application)
  subnet_id      = aws_subnet.application[count.index].id
  route_table_id = aws_route_table.application.id
}

# Application tier security group
resource "aws_security_group" "application" {
  name        = "${local.name}-application-sg"
  description = "Security group for application tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTPS from ALB"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.cde_subnets
    description = "HTTPS to CDE for tokenization"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to external services"
  }

  tags = merge(local.common_tags, { Name = "${local.name}-application-sg" })
}

# ------------------------------------------------------------------------------
# ALB SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.application_subnets
    description = "HTTPS to application tier"
  }

  tags = merge(local.common_tags, { Name = "${local.name}-alb-sg" })
}

# ------------------------------------------------------------------------------
# CDE NETWORK MODULE
# ------------------------------------------------------------------------------

module "cde_network" {
  source = "../../modules/cde-network"

  name                           = local.name
  vpc_id                         = aws_vpc.main.id
  vpc_cidr_block                 = local.vpc_cidr
  cde_cidr_blocks                = local.cde_subnets
  availability_zones             = local.azs
  application_security_group_id  = aws_security_group.application.id
  application_subnet_cidr_blocks = local.application_subnets

  enable_vpc_endpoints    = true
  enable_flow_logs        = true
  flow_log_retention_days = 365

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# SECRETS MANAGEMENT MODULE
# ------------------------------------------------------------------------------

module "secrets" {
  source = "../../modules/secrets-management"

  name        = local.name
  environment = var.environment

  create_kms_key      = true
  enable_key_rotation = true

  secrets = {
    "database/card-vault" = {
      description     = "Card vault database credentials"
      recovery_window = 30
    }
    "api/payment-gateway" = {
      description = "External payment gateway API credentials"
    }
    "api/card-networks" = {
      description = "Visa/Mastercard network credentials"
    }
  }

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# API GATEWAY MODULE
# ------------------------------------------------------------------------------

module "api_gateway" {
  source = "../../modules/api-gateway"

  name        = local.name
  environment = var.environment
  description = "NovaPay Payment Processing API"

  enable_waf     = true
  waf_rate_limit = 2000

  throttle_burst_limit = 100
  throttle_rate_limit  = 1000
  quota_limit          = 1000000

  enable_access_logs = true
  log_retention_days = 365

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# TOKENIZATION MODULE
# ------------------------------------------------------------------------------

module "tokenization" {
  source = "../../modules/tokenization"

  name        = local.name
  environment = var.environment

  # Network
  vpc_id            = aws_vpc.main.id
  subnet_ids        = module.cde_network.cde_subnet_ids
  security_group_id = module.cde_network.tokenization_security_group_id

  # Container
  container_image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.name}-tokenization:latest"
  cpu             = 512
  memory          = 1024
  desired_count   = 2

  # Database
  database_subnet_ids        = module.cde_network.cde_subnet_ids
  database_security_group_id = module.cde_network.card_vault_security_group_id
  database_instance_class    = "db.t3.medium"
  database_multi_az          = true

  # Encryption
  kms_key_arn = module.secrets.kms_key_arn

  # Secrets
  database_credentials_secret_arn = module.secrets.secret_arns["database/card-vault"]

  log_retention_days = 365

  tags = local.common_tags
}
