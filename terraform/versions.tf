terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Recommended for team use: keep state in an encrypted, versioned S3 bucket
  # with DynamoDB locking. Create the bucket/table first, then uncomment.
  #
  # backend "s3" {
  #   bucket         = "<your-terraform-state-bucket>"
  #   key            = "document-management-platform/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "<your-terraform-lock-table>"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}
