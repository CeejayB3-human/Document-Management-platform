output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "document_bucket_name" {
  description = "S3 bucket that stores documents."
  value       = aws_s3_bucket.documents.bucket
}

output "lambda_function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.document_management.function_name
}

output "rds_endpoint" {
  description = "Private endpoint of the RDS instance."
  value       = aws_db_instance.metadata.address
}

output "db_secret_name" {
  description = "Secrets Manager secret holding the database credentials."
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "backup_vault_name" {
  description = "AWS Backup vault name."
  value       = aws_backup_vault.this.name
}
