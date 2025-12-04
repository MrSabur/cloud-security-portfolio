# ------------------------------------------------------------------------------
# CDE NETWORK MODULE - OUTPUTS
# ------------------------------------------------------------------------------

output "cde_subnet_ids" {
  description = "IDs of CDE subnets"
  value       = aws_subnet.cde[*].id
}

output "cde_subnet_cidr_blocks" {
  description = "CIDR blocks of CDE subnets"
  value       = aws_subnet.cde[*].cidr_block
}

output "cde_route_table_id" {
  description = "Route table ID for CDE subnets"
  value       = aws_route_table.cde.id
}

output "tokenization_security_group_id" {
  description = "Security group ID for tokenization service"
  value       = aws_security_group.tokenization.id
}

output "payment_processor_security_group_id" {
  description = "Security group ID for payment processor service"
  value       = aws_security_group.payment_processor.id
}

output "card_vault_security_group_id" {
  description = "Security group ID for card vault database"
  value       = aws_security_group.card_vault.id
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = var.enable_vpc_endpoints ? aws_security_group.vpc_endpoints[0].id : null
}

output "flow_log_group_name" {
  description = "CloudWatch Log Group name for flow logs"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.cde_flow_logs[0].name : null
}

output "nacl_id" {
  description = "Network ACL ID for CDE subnets"
  value       = aws_network_acl.cde.id
}
