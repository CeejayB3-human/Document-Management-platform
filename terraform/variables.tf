# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for resources that do not have an explicit name variable."
  type        = string
  default     = "cleatpath"
}

variable "tags" {
  description = "Tags applied to every resource via the provider's default_tags."
  type        = map(string)
  default = {
    Project   = "Document Management and Client Records Platform"
    ManagedBy = "terraform"
  }
}

variable "alert_email" {
  description = "Optional e-mail address subscribed to the alarm and backup SNS topics. Leave empty to skip."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets. One subnet is created per entry, each in a different Availability Zone (minimum two for RDS Multi-AZ)."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "Provide at least two private subnet CIDRs (RDS Multi-AZ needs two Availability Zones)."
  }
}

variable "rds_security_group_name" {
  description = "Name of the RDS security group."
  type        = string
  default     = "ClearPath-RDS-SG"
}

# ---------------------------------------------------------------------------
# S3
# ---------------------------------------------------------------------------
variable "document_bucket_name" {
  description = "Globally unique name of the S3 bucket that stores documents."
  type        = string
  default     = "cleatpath-document-management"
}

variable "archive_after_days" {
  description = "Days after object creation before objects transition to S3 Glacier Flexible Retrieval."
  type        = number
  default     = 30
}

# ---------------------------------------------------------------------------
# RDS
# ---------------------------------------------------------------------------
variable "db_instance_identifier" {
  description = "RDS DB instance identifier."
  type        = string
  default     = "clearpath-document-db"
}

variable "db_name" {
  description = "Name of the initial database."
  type        = string
  default     = "document_management_db"
}

variable "db_username" {
  description = "Master username for the database."
  type        = string
  default     = "admin"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB (gp3)."
  type        = number
  default     = 20
}

variable "db_backup_retention_days" {
  description = "Retention (days) for RDS automated backups."
  type        = number
  default     = 7
}

variable "rds_deletion_protection" {
  description = "Protect the DB instance from accidental deletion. Set to false before running terraform destroy."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Secrets Manager
# ---------------------------------------------------------------------------
variable "secret_name" {
  description = "Name of the Secrets Manager secret that holds the database credentials."
  type        = string
  default     = "clearpath-rds-secret"
}

variable "secret_recovery_window_days" {
  description = "Recovery window (days) when the secret is deleted. Use 0 to delete immediately (needed to re-create a secret of the same name right after destroy)."
  type        = number
  default     = 7
}

# ---------------------------------------------------------------------------
# Lambda
# ---------------------------------------------------------------------------
variable "lambda_function_name" {
  description = "Name of the Lambda function."
  type        = string
  default     = "document-management"
}

variable "lambda_role_name" {
  description = "Name of the Lambda execution role."
  type        = string
  default     = "document-management-lambda-role"
}

variable "lambda_runtime" {
  description = "Lambda runtime (Python)."
  type        = string
  default     = "python3.12"
}

variable "lambda_memory_mb" {
  description = "Lambda memory size in MB."
  type        = number
  default     = 512
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 30
}

variable "presigned_url_expiry_seconds" {
  description = "Lifetime of pre-signed download URLs issued by the Lambda function."
  type        = number
  default     = 900
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the Lambda log group."
  type        = number
  default     = 30
}

# ---------------------------------------------------------------------------
# AWS Backup
# ---------------------------------------------------------------------------
variable "backup_schedule" {
  description = "Cron expression (UTC) for the AWS Backup plan."
  type        = string
  default     = "cron(0 3 * * ? *)"
}

variable "backup_retention_days" {
  description = "Days AWS Backup keeps each recovery point."
  type        = number
  default     = 30
}
