# ------------------------------------------------------------------------------
# VPC MODULE
# Creates a three-tier VPC with public, private, and data subnets
# Designed for HIPAA-compliant healthcare workloads
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
# DATA SOURCES
# Fetch information from AWS that we need for configuration
# ------------------------------------------------------------------------------

# Get available AZs in the current region
data "aws_availability_zones" "available" {
  state = "available"

  # Exclude Local Zones and Wavelength Zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Get current AWS region
data "aws_region" "current" {}

# ------------------------------------------------------------------------------
# LOCAL VALUES
# Computed values used throughout the module
# ------------------------------------------------------------------------------

locals {
  # Use provided AZs or default to first 2 available
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)

  # Calculate subnet CIDR blocks from VPC CIDR
  # VPC: 10.20.0.0/16 → Public: 10.20.0.0/24, 10.20.1.0/24
  #                   → Private: 10.20.10.0/24, 10.20.11.0/24
  #                   → Data: 10.20.20.0/24, 10.20.21.0/24
  vpc_cidr_prefix = split(".", var.cidr_block)[0]  # "10"
  vpc_cidr_second = split(".", var.cidr_block)[1]  # "20"

  # Standard tags applied to all resources
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "vpc"
      Project     = "medflow-landing-zone"
    },
    var.tags
  )
}

# ------------------------------------------------------------------------------
# VPC
# The virtual network container for all resources
# ------------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true  # Required for RDS, ECS, and other services
  enable_dns_support   = true  # Required for VPC endpoints

  tags = merge(local.common_tags, {
    Name = "${var.name}-vpc"
  })
}

# ------------------------------------------------------------------------------
# INTERNET GATEWAY
# Allows resources in public subnets to reach the internet
# ------------------------------------------------------------------------------

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-igw"
  })
}

# ------------------------------------------------------------------------------
# PUBLIC SUBNETS
# For load balancers and NAT gateways only
# These have a route to the Internet Gateway
# ------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = length(local.azs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index)  # /16 → /24
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false  # Never auto-assign public IPs (security best practice)

  tags = merge(local.common_tags, {
    Name = "${var.name}-public-${local.azs[count.index]}"
    Tier = "public"
  })
}

# Public route table - routes to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = length(local.azs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# NAT GATEWAY
# Allows private subnets to reach the internet (outbound only)
# Placed in public subnet but serves private subnets
# ------------------------------------------------------------------------------

# Elastic IP for NAT Gateway (NAT needs a static public IP)
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.azs)) : 0

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.name}-nat-eip-${count.index + 1}"
  })

  # EIP may require IGW to exist
  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.azs)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id  # NAT GW lives in public subnet

  tags = merge(local.common_tags, {
    Name = "${var.name}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}

# ------------------------------------------------------------------------------
# PRIVATE SUBNETS
# For application servers (ECS, EC2)
# Can reach internet via NAT Gateway (outbound only)
# ------------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count = length(local.azs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index + 10)  # 10.20.10.0/24, 10.20.11.0/24
  availability_zone = local.azs[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.name}-private-${local.azs[count.index]}"
    Tier = "private"
  })
}

# Private route tables - one per AZ for AZ-independent routing
resource "aws_route_table" "private" {
  count = length(local.azs)

  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-private-rt-${local.azs[count.index]}"
  })
}

# Route to NAT Gateway for internet access
resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? length(local.azs) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private" {
  count = length(local.azs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ------------------------------------------------------------------------------
# DATA SUBNETS
# For databases (RDS, ElastiCache)
# NO internet access - not even outbound
# This is critical for HIPAA: PHI cannot be exfiltrated directly
# ------------------------------------------------------------------------------

resource "aws_subnet" "data" {
  count = length(local.azs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index + 20)  # 10.20.20.0/24, 10.20.21.0/24
  availability_zone = local.azs[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.name}-data-${local.azs[count.index]}"
    Tier = "data"
  })
}

# Data route table - NO route to internet
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id

  # Note: No route to 0.0.0.0/0 - this is intentional
  # Data tier resources cannot reach the internet

  tags = merge(local.common_tags, {
    Name = "${var.name}-data-rt"
  })
}

resource "aws_route_table_association" "data" {
  count = length(local.azs)

  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

# ------------------------------------------------------------------------------
# VPC FLOW LOGS
# Capture all network traffic metadata for HIPAA audit requirements
# ------------------------------------------------------------------------------

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  iam_role_arn             = aws_iam_role.flow_log[0].arn
  log_destination          = aws_cloudwatch_log_group.flow_log[0].arn
  log_destination_type     = "cloud-watch-logs"
  max_aggregation_interval = 60  # 1 minute intervals for timely detection

  tags = merge(local.common_tags, {
    Name = "${var.name}-flow-log"
  })
}

resource "aws_cloudwatch_log_group" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/flow-logs/${var.name}"
  retention_in_days = var.flow_log_retention_days

  tags = local.common_tags
}

# IAM role for VPC Flow Logs to write to CloudWatch
resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-vpc-flow-log-policy"
  role = aws_iam_role.flow_log[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# VPC ENDPOINTS
# Allow private subnets to access AWS services without internet
# Critical for data tier: can access S3, SSM without NAT
# ------------------------------------------------------------------------------

# S3 Gateway Endpoint (free, no data charges)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id,
    [aws_route_table.data.id]
  )

  tags = merge(local.common_tags, {
    Name = "${var.name}-s3-endpoint"
  })
}

# DynamoDB Gateway Endpoint (free, useful for state locking)
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id,
    [aws_route_table.data.id]
  )

  tags = merge(local.common_tags, {
    Name = "${var.name}-dynamodb-endpoint"
  })
}