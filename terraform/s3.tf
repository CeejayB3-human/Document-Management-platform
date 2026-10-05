# ---------------------------------------------------------------------------
# Document bucket (new objects land in S3 Standard)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "documents" {
  bucket = var.document_bucket_name

  tags = {
    Name = var.document_bucket_name
  }
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# Lifecycle: archive to S3 Glacier Flexible Retrieval after N days
# (Terraform storage class "GLACIER" = Glacier Flexible Retrieval)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    id     = "archive-to-glacier-flexible-retrieval"
    status = "Enabled"

    filter {}

    transition {
      days          = var.archive_after_days
      storage_class = "GLACIER"
    }
  }

  depends_on = [aws_s3_bucket_versioning.documents]
}

# ---------------------------------------------------------------------------
# Event notification: every new object invokes the Lambda function
# ---------------------------------------------------------------------------
resource "aws_lambda_permission" "allow_s3" {
  statement_id   = "AllowExecutionFromS3Bucket"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.document_management.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.documents.arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "documents" {
  bucket = aws_s3_bucket.documents.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.document_management.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
