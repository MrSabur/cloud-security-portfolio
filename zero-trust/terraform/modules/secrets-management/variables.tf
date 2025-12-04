# ------------------------------------------------------------------------------
# SECRETS MANAGEMENT MODULE - VARIABLES
# ------------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# ------------------------------------------------------------------------------
# KMS
# ------------------------------------------------------------------------------

variable "create_kms_key" {
  description = "Create a KMS key for encrypting secrets"
  type        = bool
  default     = true
}

variable "kms_key_deletion_window" {
  description = "Days before KMS key is deleted (7-30)"
  type        = number
  default     = 30
}

variable "enable_key_rotation" {
  description = "Enable automatic annual key rotation"
  type        = bool
  default     = true
}

variable "key_admin_role_arns" {
  description = "IAM role ARNs that can administer the KMS key"
  type        = list(string)
  default     = []
}

variable "key_user_role_arns" {
  description = "IAM role ARNs that can use the KMS key for encrypt/decrypt"
  type        = list(string)
  default     = []
}

# ------------------------------------------------------------------------------
# SECRETS
# ------------------------------------------------------------------------------

variable "secrets" {
  description = "Map of secrets to create"
  type = map(object({
    description         = string
    recovery_window     = optional(number, 30)
    enable_rotation     = optional(bool, false)
    rotation_lambda_arn = optional(string, null)
    rotation_days       = optional(number, 30)
  }))
  default = {}
}

# ------------------------------------------------------------------------------
# TAGS
# ------------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
