# ------------------------------------------------------------------------------
# API GATEWAY MODULE - OUTPUTS
# ------------------------------------------------------------------------------

output "api_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_arn" {
  description = "ARN of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_execution_arn" {
  description = "Execution ARN for invoking the API"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "api_endpoint" {
  description = "Base URL of the API"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "stage_name" {
  description = "Name of the deployed stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "stage_arn" {
  description = "ARN of the deployed stage"
  value       = aws_api_gateway_stage.main.arn
}

output "standard_usage_plan_id" {
  description = "ID of standard usage plan"
  value       = aws_api_gateway_usage_plan.standard.id
}

output "enterprise_usage_plan_id" {
  description = "ID of enterprise usage plan"
  value       = aws_api_gateway_usage_plan.enterprise.id
}

output "waf_web_acl_arn" {
  description = "ARN of WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.api[0].arn : null
}

output "access_log_group_name" {
  description = "CloudWatch Log Group for access logs"
  value       = var.enable_access_logs ? aws_cloudwatch_log_group.access_logs[0].name : null
}

output "waf_log_group_name" {
  description = "CloudWatch Log Group for WAF logs"
  value       = var.enable_waf ? aws_cloudwatch_log_group.waf_logs[0].name : null
}
