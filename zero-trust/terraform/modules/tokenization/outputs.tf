# ------------------------------------------------------------------------------
# TOKENIZATION MODULE - OUTPUTS
# ------------------------------------------------------------------------------

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.tokenization.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.tokenization.name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.tokenization.name
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.tokenization.arn
}

output "execution_role_arn" {
  description = "ARN of the ECS execution role"
  value       = aws_iam_role.ecs_execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "card_vault_endpoint" {
  description = "RDS endpoint for card vault"
  value       = aws_db_instance.card_vault.endpoint
}

output "card_vault_address" {
  description = "RDS address (hostname only)"
  value       = aws_db_instance.card_vault.address
}

output "card_vault_port" {
  description = "RDS port"
  value       = aws_db_instance.card_vault.port
}

output "card_vault_database_name" {
  description = "Database name"
  value       = aws_db_instance.card_vault.db_name
}

output "card_vault_master_secret_arn" {
  description = "ARN of the secret containing master credentials"
  value       = aws_db_instance.card_vault.master_user_secret[0].secret_arn
}

output "service_discovery_namespace_id" {
  description = "ID of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.cde.id
}

output "service_discovery_service_arn" {
  description = "ARN of the service discovery service"
  value       = aws_service_discovery_service.tokenization.arn
}

output "tokenization_dns_name" {
  description = "Internal DNS name for tokenization service"
  value       = "tokenization.${var.name}.cde.internal"
}

output "log_group_name" {
  description = "CloudWatch log group for tokenization service"
  value       = aws_cloudwatch_log_group.tokenization.name
}
