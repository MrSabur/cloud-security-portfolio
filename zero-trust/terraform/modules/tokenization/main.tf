# ------------------------------------------------------------------------------
# TOKENIZATION MODULE
# Core service for converting card numbers to tokens
#
# Components:
#   - ECS Fargate service (tokenization application)
#   - RDS PostgreSQL (card vault - stores encrypted PANs)
#   - IAM roles with least-privilege permissions
#   - CloudWatch logging for audit trail
#
# Security controls:
#   - Runs in CDE subnet (no internet access)
#   - Only KMS encrypt/decrypt for card-encryption key
#   - Database credentials from Secrets Manager
#   - All traffic encrypted (TLS)
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

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
  common_tags = merge(
    { Module = "tokenization", PCI_Scope = "true", Compliance = "pci-dss" },
    var.tags
  )
}

# ------------------------------------------------------------------------------
# ECS CLUSTER
# ------------------------------------------------------------------------------

resource "aws_ecs_cluster" "tokenization" {
  name = "${var.name}-tokenization"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.common_tags, { Name = "${var.name}-tokenization-cluster" })
}

# ------------------------------------------------------------------------------
# ECS TASK DEFINITION
# ------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "tokenization" {
  family                   = "${var.name}-tokenization"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "tokenization"
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "ENVIRONMENT", value = var.environment },
        { name = "AWS_REGION", value = local.region },
        { name = "KMS_KEY_ARN", value = var.kms_key_arn },
        { name = "DB_HOST", value = aws_db_instance.card_vault.address },
        { name = "DB_PORT", value = tostring(aws_db_instance.card_vault.port) },
        { name = "DB_NAME", value = aws_db_instance.card_vault.db_name }
      ]

      secrets = [
        {
          name      = "DB_CREDENTIALS"
          valueFrom = var.database_credentials_secret_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.tokenization.name
          awslogs-region        = local.region
          awslogs-stream-prefix = "tokenization"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(local.common_tags, { Name = "${var.name}-tokenization-task" })
}
# ------------------------------------------------------------------------------
# ECS SERVICE
# ------------------------------------------------------------------------------
resource "aws_ecs_service" "tokenization" {
  name            = "${var.name}-tokenization"
  cluster         = aws_ecs_cluster.tokenization.id
  task_definition = aws_ecs_task_definition.tokenization.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = false
  }

  health_check_grace_period_seconds = 120
  enable_execute_command            = true

  service_registries {
    registry_arn = aws_service_discovery_service.tokenization.arn
  }

  tags = merge(local.common_tags, { Name = "${var.name}-tokenization-service" })

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# ------------------------------------------------------------------------------
# IAM ROLE - ECS EXECUTION (pulls images, writes logs, gets secrets)
# ------------------------------------------------------------------------------

resource "aws_iam_role" "ecs_execution" {
  name = "${var.name}-tokenization-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "ecs_execution" {
  name = "${var.name}-tokenization-execution"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PullContainerImages"
        Effect   = "Allow"
        Action   = ["ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid      = "WriteLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.tokenization.arn}:*"
      },
      {
        Sid      = "GetDatabaseCredentials"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.database_credentials_secret_arn
      },
      {
        Sid      = "DecryptSecrets"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = var.kms_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${local.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# IAM ROLE - ECS TASK (application permissions)
# ------------------------------------------------------------------------------

resource "aws_iam_role" "ecs_task" {
  name = "${var.name}-tokenization-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "ecs_task" {
  name = "${var.name}-tokenization-task"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EncryptDecryptCardData"
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      },
      {
        Sid      = "ECSExec"
        Effect   = "Allow"
        Action   = ["ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]
        Resource = "*"
      },
      {
        Sid      = "ECSExecLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.ecs_exec.arn}:*"
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# RDS - CARD VAULT DATABASE
# ------------------------------------------------------------------------------

resource "aws_db_subnet_group" "card_vault" {
  name       = "${var.name}-card-vault"
  subnet_ids = var.database_subnet_ids

  tags = merge(local.common_tags, { Name = "${var.name}-card-vault-subnet-group" })
}

resource "aws_db_instance" "card_vault" {
  identifier = "${var.name}-card-vault"

  engine                = "postgres"
  engine_version        = "15.4"
  instance_class        = var.database_instance_class
  allocated_storage     = var.database_allocated_storage
  max_allocated_storage = var.database_allocated_storage * 10

  db_name  = "cardvault"
  username = "vaultadmin"

  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.card_vault.name
  vpc_security_group_ids = [var.database_security_group_id]
  publicly_accessible    = false
  port                   = 5432

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  multi_az = var.database_multi_az

  backup_retention_period   = 35
  backup_window             = "03:00-04:00"
  maintenance_window        = "Mon:04:00-Mon:05:00"
  copy_tags_to_snapshot     = true
  delete_automated_backups  = false
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.name}-card-vault-final"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = var.kms_key_arn

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  tags = merge(local.common_tags, { Name = "${var.name}-card-vault" })
}

# ------------------------------------------------------------------------------
# RDS MONITORING ROLE
# ------------------------------------------------------------------------------

resource "aws_iam_role" "rds_monitoring" {
  name = "${var.name}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ------------------------------------------------------------------------------
# CLOUDWATCH LOG GROUPS
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "tokenization" {
  name              = "/aws/ecs/${var.name}-tokenization"
  retention_in_days = var.log_retention_days
  tags              = merge(local.common_tags, { Name = "${var.name}-tokenization-logs" })
}

resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/aws/ecs/${var.name}-tokenization-exec"
  retention_in_days = var.log_retention_days
  tags              = merge(local.common_tags, { Name = "${var.name}-tokenization-exec-logs" })
}

# ------------------------------------------------------------------------------
# SERVICE DISCOVERY (internal DNS)
# ------------------------------------------------------------------------------

resource "aws_service_discovery_private_dns_namespace" "cde" {
  name        = "${var.name}.cde.internal"
  description = "Private DNS namespace for CDE services"
  vpc         = var.vpc_id

  tags = local.common_tags
}

resource "aws_service_discovery_service" "tokenization" {
  name = "tokenization"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.cde.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = local.common_tags
}
