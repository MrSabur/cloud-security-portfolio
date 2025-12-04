# ------------------------------------------------------------------------------
# CDE NETWORK MODULE
# Creates isolated network for Cardholder Data Environment
#
# Key security controls:
#   - No internet gateway route
#   - No NAT gateway route
#   - VPC endpoints for AWS services only
#   - NACL restricts traffic to application tier
#   - Security groups reference other SGs, not CIDRs
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
# ------------------------------------------------------------------------------

data "aws_region" "current" {}

# ------------------------------------------------------------------------------
# LOCAL VALUES
# ------------------------------------------------------------------------------

locals {
  region = data.aws_region.current.name

  common_tags = merge(
    {
      Module     = "cde-network"
      PCI_Scope  = "true"
      Compliance = "pci-dss"
    },
    var.tags
  )

  # VPC endpoints required for CDE (no internet access)
  required_endpoints = [
    "kms",
    "secretsmanager",
    "sts",
    "logs",
    "ecr.api",
    "ecr.dkr"
  ]

  gateway_endpoints = ["s3", "dynamodb"]
}

# ------------------------------------------------------------------------------
# CDE SUBNETS
# Private subnets with NO route to internet
# ------------------------------------------------------------------------------

resource "aws_subnet" "cde" {
  count = length(var.cde_cidr_blocks)

  vpc_id                  = var.vpc_id
  cidr_block              = var.cde_cidr_blocks[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.name}-cde-${var.availability_zones[count.index]}"
    Tier = "cde"
  })
}

# ------------------------------------------------------------------------------
# CDE ROUTE TABLE
# No route to internet - only local VPC traffic and endpoints
# ------------------------------------------------------------------------------

resource "aws_route_table" "cde" {
  vpc_id = var.vpc_id

  # No routes added - only local VPC routing
  # VPC endpoints will add their own routes for gateway endpoints

  tags = merge(local.common_tags, {
    Name = "${var.name}-cde-rt"
  })
}

resource "aws_route_table_association" "cde" {
  count = length(aws_subnet.cde)

  subnet_id      = aws_subnet.cde[count.index].id
  route_table_id = aws_route_table.cde.id
}

# ------------------------------------------------------------------------------
# NETWORK ACL
# Defense in depth - explicit allow/deny at subnet boundary
# ------------------------------------------------------------------------------

resource "aws_network_acl" "cde" {
  vpc_id     = var.vpc_id
  subnet_ids = aws_subnet.cde[*].id

  tags = merge(local.common_tags, {
    Name = "${var.name}-cde-nacl"
  })
}

# Allow inbound HTTPS from application tier
resource "aws_network_acl_rule" "cde_inbound_https" {
  count = length(var.application_subnet_cidr_blocks)

  network_acl_id = aws_network_acl.cde.id
  rule_number    = 100 + count.index
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.application_subnet_cidr_blocks[count.index]
  from_port      = 443
  to_port        = 443
}

# Allow inbound ephemeral ports (return traffic from VPC endpoints)
resource "aws_network_acl_rule" "cde_inbound_ephemeral" {
  network_acl_id = aws_network_acl.cde.id
  rule_number    = 200
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr_block
  from_port      = 1024
  to_port        = 65535
}

# Deny all other inbound
resource "aws_network_acl_rule" "cde_inbound_deny" {
  network_acl_id = aws_network_acl.cde.id
  rule_number    = 999
  egress         = false
  protocol       = -1
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

# Allow outbound to VPC (for endpoints)
resource "aws_network_acl_rule" "cde_outbound_vpc" {
  network_acl_id = aws_network_acl.cde.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr_block
  from_port      = 443
  to_port        = 443
}

# Allow outbound ephemeral (responses to application tier)
resource "aws_network_acl_rule" "cde_outbound_ephemeral" {
  count = length(var.application_subnet_cidr_blocks)

  network_acl_id = aws_network_acl.cde.id
  rule_number    = 200 + count.index
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.application_subnet_cidr_blocks[count.index]
  from_port      = 1024
  to_port        = 65535
}

# Deny all other outbound (NO INTERNET)
resource "aws_network_acl_rule" "cde_outbound_deny" {
  network_acl_id = aws_network_acl.cde.id
  rule_number    = 999
  egress         = true
  protocol       = -1
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

# ------------------------------------------------------------------------------
# SECURITY GROUPS
# ------------------------------------------------------------------------------

# Security group for tokenization service (entry point to CDE)
resource "aws_security_group" "tokenization" {
  name        = "${var.name}-tokenization-sg"
  description = "Security group for tokenization service"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.name}-tokenization-sg"
  })
}

# Allow inbound from application tier only
resource "aws_security_group_rule" "tokenization_inbound" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = var.application_security_group_id
  security_group_id        = aws_security_group.tokenization.id
  description              = "HTTPS from application tier"
}

# Allow outbound to VPC endpoints
resource "aws_security_group_rule" "tokenization_outbound_endpoints" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vpc_endpoints.id
  security_group_id        = aws_security_group.tokenization.id
  description              = "HTTPS to VPC endpoints"
}

# Allow outbound to payment processor (within CDE)
resource "aws_security_group_rule" "tokenization_outbound_payment" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.payment_processor.id
  security_group_id        = aws_security_group.tokenization.id
  description              = "HTTPS to payment processor"
}

# Security group for payment processor
resource "aws_security_group" "payment_processor" {
  name        = "${var.name}-payment-processor-sg"
  description = "Security group for payment processor service"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.name}-payment-processor-sg"
  })
}

# Allow inbound from tokenization service only
resource "aws_security_group_rule" "payment_inbound_tokenization" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tokenization.id
  security_group_id        = aws_security_group.payment_processor.id
  description              = "HTTPS from tokenization service"
}

# Allow outbound to VPC endpoints
resource "aws_security_group_rule" "payment_outbound_endpoints" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vpc_endpoints.id
  security_group_id        = aws_security_group.payment_processor.id
  description              = "HTTPS to VPC endpoints"
}

# Allow outbound to card vault (RDS)
resource "aws_security_group_rule" "payment_outbound_vault" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.card_vault.id
  security_group_id        = aws_security_group.payment_processor.id
  description              = "PostgreSQL to card vault"
}

# Security group for card vault (RDS)
resource "aws_security_group" "card_vault" {
  name        = "${var.name}-card-vault-sg"
  description = "Security group for card vault database"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.name}-card-vault-sg"
  })
}

# Allow inbound from tokenization and payment processor
resource "aws_security_group_rule" "vault_inbound_tokenization" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tokenization.id
  security_group_id        = aws_security_group.card_vault.id
  description              = "PostgreSQL from tokenization service"
}

resource "aws_security_group_rule" "vault_inbound_payment" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.payment_processor.id
  security_group_id        = aws_security_group.card_vault.id
  description              = "PostgreSQL from payment processor"
}

# No egress from vault - it only receives queries

# ------------------------------------------------------------------------------
# VPC ENDPOINTS
# Required for CDE to access AWS services without internet
# ------------------------------------------------------------------------------

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_vpc_endpoints ? 1 : 0

  name        = "${var.name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.cde_cidr_blocks
    description = "HTTPS from CDE subnets"
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-vpc-endpoints-sg"
  })
}

# Interface endpoints (KMS, Secrets Manager, STS, Logs, ECR)
resource "aws_vpc_endpoint" "interface" {
  for_each = var.enable_vpc_endpoints ? toset(local.required_endpoints) : []

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${local.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.cde[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.name}-${each.key}-endpoint"
  })
}

# Gateway endpoints (S3, DynamoDB) - free, added to route table
resource "aws_vpc_endpoint" "gateway" {
  for_each = var.enable_vpc_endpoints ? toset(local.gateway_endpoints) : []

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${local.region}.${each.key}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.cde.id]

  tags = merge(local.common_tags, {
    Name = "${var.name}-${each.key}-endpoint"
  })
}

# ------------------------------------------------------------------------------
# FLOW LOGS
# Audit trail for all network traffic in CDE
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "cde_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/flow-logs/${var.name}-cde"
  retention_in_days = var.flow_log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.name}-cde-flow-logs"
  })
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-cde-flow-logs-role"

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

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-cde-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# Flow log for each CDE subnet
resource "aws_flow_log" "cde" {
  count = var.enable_flow_logs ? length(aws_subnet.cde) : 0

  subnet_id       = aws_subnet.cde[count.index].id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.cde_flow_logs[0].arn

  tags = merge(local.common_tags, {
    Name = "${var.name}-cde-flow-log-${count.index}"
  })
}
