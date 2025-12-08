# ------------------------------------------------------------------------------
# TOKENIZATION MODULE - VARIABLES
# ------------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name (live/test)"
  type        = string
  default     = "live"
}

# ------------------------------------------------------------------------------
# NETWORKING
# ------------------------------------------------------------------------------

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for tokenization service (CDE subnets)"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for tokenization service"
  type        = string
}

# ------------------------------------------------------------------------------
# CONTAINER
# ------------------------------------------------------------------------------

variable "container_image" {
  description = "Container image for tokenization service"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 443
}

variable "cpu" {
  description = "CPU units for Fargate task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Memory in MB for Fargate task"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Number of tasks to run"
  type        = number
  default     = 2
}

# ------------------------------------------------------------------------------
# DATABASE (Card Vault)
# ------------------------------------------------------------------------------

variable "database_subnet_ids" {
  description = "Subnet IDs for RDS (should be CDE subnets)"
  type        = list(string)
}

variable "database_security_group_id" {
  description = "Security group ID for card vault database"
  type        = string
}

variable "database_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "database_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "database_multi_az" {
  description = "Enable Multi-AZ for high availability"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# ENCRYPTION
# ------------------------------------------------------------------------------

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting card data"
  type        = string
}

# ------------------------------------------------------------------------------
# SECRETS
# ------------------------------------------------------------------------------

variable "database_credentials_secret_arn" {
  description = "Secrets Manager ARN for database credentials"
  type        = string
}

# ------------------------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 365
}

# ------------------------------------------------------------------------------
# TAGS
# ------------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
