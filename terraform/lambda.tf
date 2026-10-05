# ---------------------------------------------------------------------------
# IAM execution role
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = var.lambda_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# CloudWatch Logs + the network interface permissions Lambda needs to run in a VPC.
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "lambda_access" {
  statement {
    sid       = "ReadDocuments"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.documents.arn}/*"]
  }

  statement {
    sid       = "ReadDatabaseSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db_credentials.arn]
  }
}

resource "aws_iam_role_policy" "lambda_access" {
  name   = "${var.lambda_role_name}-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_access.json
}

# ---------------------------------------------------------------------------
# PyMySQL layer (build it first with scripts/build_layer.sh)
# ---------------------------------------------------------------------------
resource "aws_lambda_layer_version" "pymysql" {
  layer_name          = "${var.project_name}-pymysql"
  description         = "PyMySQL client library"
  filename            = "${path.module}/../build/pymysql_layer.zip"
  source_code_hash    = filebase64sha256("${path.module}/../build/pymysql_layer.zip")
  compatible_runtimes = [var.lambda_runtime]
}

# ---------------------------------------------------------------------------
# Function code is packaged from ../src
# ---------------------------------------------------------------------------
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/../build/document_management.zip"
}

# Created explicitly so retention is managed and Lambda does not create it first.
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "document_management" {
  function_name = var.lambda_function_name
  description   = "Captures document metadata on S3 upload and stores it in Amazon RDS"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda.arn
  layers           = [aws_lambda_layer_version.pymysql.arn]

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SECRET_NAME                  = aws_secretsmanager_secret.db_credentials.name
      DB_NAME                      = var.db_name
      BUCKET_NAME                  = aws_s3_bucket.documents.bucket
      PRESIGNED_URL_EXPIRY_SECONDS = tostring(var.presigned_url_expiry_seconds)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy.lambda_access,
  ]
}
