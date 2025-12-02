# ------------------------------------------------------------------------------
# SECURITY BASELINE MODULE - OUTPUTS
# ------------------------------------------------------------------------------

# CloudTrail outputs
output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].arn : null
}

output "cloudtrail_s3_bucket_name" {
  description = "Name of the S3 bucket storing CloudTrail logs"
  value       = var.enable_cloudtrail ? aws_s3_bucket.cloudtrail[0].id : null
}

output "cloudtrail_s3_bucket_arn" {
  description = "ARN of the S3 bucket storing CloudTrail logs"
  value       = var.enable_cloudtrail ? aws_s3_bucket.cloudtrail[0].arn : null
}

# GuardDuty outputs
output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

# Config outputs
output "config_recorder_id" {
  description = "ID of the AWS Config recorder"
  value       = var.enable_config ? aws_config_configuration_recorder.main[0].id : null
}

output "config_s3_bucket_name" {
  description = "Name of the S3 bucket storing Config snapshots"
  value       = var.enable_config ? aws_s3_bucket.config[0].id : null
}

# Security Hub outputs
output "security_hub_arn" {
  description = "ARN of the Security Hub subscription"
  value       = var.enable_security_hub ? aws_securityhub_account.main[0].arn : null
}

# Summary output for easy reference
output "security_services_enabled" {
  description = "Map of which security services are enabled"
  value = {
    cloudtrail   = var.enable_cloudtrail
    guardduty    = var.enable_guardduty
    config       = var.enable_config
    security_hub = var.enable_security_hub
  }
}