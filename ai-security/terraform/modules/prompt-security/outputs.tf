################################################################################
# WAF Outputs
################################################################################

output "waf_web_acl_arn" {
  description = "ARN of the WAF WebACL for AI API protection"
  value       = aws_wafv2_web_acl.ai_api.arn
}

output "waf_web_acl_id" {
  description = "ID of the WAF WebACL"
  value       = aws_wafv2_web_acl.ai_api.id
}

################################################################################
# Lambda Outputs
################################################################################

output "input_validator_function_arn" {
  description = "ARN of the input validation Lambda function"
  value       = aws_lambda_function.input_validator.arn
}

output "input_validator_function_name" {
  description = "Name of the input validation Lambda function"
  value       = aws_lambda_function.input_validator.function_name
}

output "output_validator_function_arn" {
  description = "ARN of the output validation Lambda function"
  value       = aws_lambda_function.output_validator.arn
}

output "output_validator_function_name" {
  description = "Name of the output validation Lambda function"
  value       = aws_lambda_function.output_validator.function_name
}

################################################################################
# Guardrail Outputs
################################################################################

output "guardrail_id" {
  description = "ID of the Bedrock guardrail for prompt security"
  value       = aws_bedrock_guardrail.prompt_security.guardrail_id
}

output "guardrail_arn" {
  description = "ARN of the Bedrock guardrail"
  value       = aws_bedrock_guardrail.prompt_security.guardrail_arn
}

output "guardrail_version" {
  description = "Version of the Bedrock guardrail"
  value       = aws_bedrock_guardrail_version.prompt_security.version
}

################################################################################
# Monitoring Outputs
################################################################################

output "input_validator_log_group" {
  description = "CloudWatch log group for input validation"
  value       = aws_cloudwatch_log_group.input_validator.name
}

output "output_validator_log_group" {
  description = "CloudWatch log group for output validation"
  value       = aws_cloudwatch_log_group.output_validator.name
}
