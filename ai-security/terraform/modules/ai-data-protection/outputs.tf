################################################################################
# KMS Outputs
################################################################################

output "kms_key_arn" {
  description = "ARN of the KMS key for AI data encryption"
  value       = aws_kms_key.ai_data.arn
}

output "kms_key_id" {
  description = "ID of the KMS key for AI data encryption"
  value       = aws_kms_key.ai_data.key_id
}

output "kms_key_alias" {
  description = "Alias of the KMS key"
  value       = aws_kms_alias.ai_data.name
}

################################################################################
# S3 Outputs
################################################################################

output "ai_data_bucket_name" {
  description = "Name of the S3 bucket for AI data"
  value       = aws_s3_bucket.ai_data.id
}

output "ai_data_bucket_arn" {
  description = "ARN of the S3 bucket for AI data"
  value       = aws_s3_bucket.ai_data.arn
}

################################################################################
# Bedrock Guardrail Outputs
################################################################################

output "guardrail_id" {
  description = "ID of the Bedrock guardrail"
  value       = aws_bedrock_guardrail.phi_protection.guardrail_id
}

output "guardrail_arn" {
  description = "ARN of the Bedrock guardrail"
  value       = aws_bedrock_guardrail.phi_protection.guardrail_arn
}

output "guardrail_version" {
  description = "Version of the Bedrock guardrail"
  value       = aws_bedrock_guardrail_version.phi_protection.version
}

################################################################################
# CloudWatch Outputs
################################################################################

output "audit_log_group_name" {
  description = "Name of the CloudWatch log group for AI audit"
  value       = aws_cloudwatch_log_group.ai_audit.name
}

output "audit_log_group_arn" {
  description = "ARN of the CloudWatch log group for AI audit"
  value       = aws_cloudwatch_log_group.ai_audit.arn
}

################################################################################
# IAM Role Outputs
################################################################################

output "tier1_role_arn" {
  description = "ARN of the Tier 1 (Standard) AI IAM role"
  value       = aws_iam_role.ai_tier1.arn
}

output "tier2_role_arn" {
  description = "ARN of the Tier 2 (Elevated) AI IAM role"
  value       = aws_iam_role.ai_tier2.arn
}

output "tier3_role_arn" {
  description = "ARN of the Tier 3 (Critical) AI IAM role"
  value       = aws_iam_role.ai_tier3.arn
}

################################################################################
# Usage Instructions
################################################################################

output "usage_instructions" {
  description = "Instructions for using this module"
  value       = <<-EOT
    AI Data Protection Module Deployed
    
    Guardrail Usage:
      Include guardrail in Bedrock API calls:
      guardrailIdentifier: ${aws_bedrock_guardrail.phi_protection.guardrail_id}
      guardrailVersion: ${aws_bedrock_guardrail_version.phi_protection.version}
    
    S3 Data Structure:
      Tier 1 (Standard): s3://${aws_s3_bucket.ai_data.id}/public/
      Tier 2 (Elevated): s3://${aws_s3_bucket.ai_data.id}/internal/
      Tier 3 (Critical): s3://${aws_s3_bucket.ai_data.id}/phi/
    
    IAM Roles:
      Tier 1: ${aws_iam_role.ai_tier1.arn}
      Tier 2: ${aws_iam_role.ai_tier2.arn}
      Tier 3: ${aws_iam_role.ai_tier3.arn}
    
    Audit Logs:
      Log all AI interactions to: ${aws_cloudwatch_log_group.ai_audit.name}
  EOT
}
