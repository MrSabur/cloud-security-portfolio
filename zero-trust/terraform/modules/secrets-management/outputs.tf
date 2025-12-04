# ------------------------------------------------------------------------------
# SECRETS MANAGEMENT MODULE - OUTPUTS
# ------------------------------------------------------------------------------

output "kms_key_id" {
  description = "ID of the KMS key"
  value       = var.create_kms_key ? aws_kms_key.secrets[0].key_id : null
}

output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = var.create_kms_key ? aws_kms_key.secrets[0].arn : null
}

output "kms_key_alias" {
  description = "Alias of the KMS key"
  value       = var.create_kms_key ? aws_kms_alias.secrets[0].name : null
}

output "secret_arns" {
  description = "Map of secret names to ARNs"
  value       = { for k, v in aws_secretsmanager_secret.main : k => v.arn }
}

output "secret_names" {
  description = "Map of secret keys to full secret names"
  value       = { for k, v in aws_secretsmanager_secret.main : k => v.name }
}

output "read_secrets_policy_arn" {
  description = "ARN of IAM policy for reading secrets"
  value       = aws_iam_policy.read_secrets.arn
}
