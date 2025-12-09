# ------------------------------------------------------------------------------
# NOVAPAY PRODUCTION - OUTPUTS
# ------------------------------------------------------------------------------

# VPC
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "application_subnet_ids" {
  description = "Application subnet IDs"
  value       = aws_subnet.application[*].id
}

# CDE Network
output "cde_subnet_ids" {
  description = "CDE subnet IDs (PCI scope)"
  value       = module.cde_network.cde_subnet_ids
}

output "tokenization_security_group_id" {
  description = "Tokenization service security group"
  value       = module.cde_network.tokenization_security_group_id
}

output "card_vault_security_group_id" {
  description = "Card vault security group"
  value       = module.cde_network.card_vault_security_group_id
}

# Secrets
output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = module.secrets.kms_key_arn
}

output "secret_arns" {
  description = "Secret ARNs"
  value       = module.secrets.secret_arns
}

# API Gateway
output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = module.api_gateway.waf_web_acl_arn
}

# Tokenization
output "tokenization_cluster_name" {
  description = "ECS cluster name"
  value       = module.tokenization.cluster_name
}

output "tokenization_service_name" {
  description = "ECS service name"
  value       = module.tokenization.service_name
}

output "tokenization_dns_name" {
  description = "Internal DNS name for tokenization service"
  value       = module.tokenization.tokenization_dns_name
}

output "card_vault_endpoint" {
  description = "RDS endpoint for card vault"
  value       = module.tokenization.card_vault_endpoint
}
