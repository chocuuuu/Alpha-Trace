terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

resource "aws_kms_key" "s3" {
  description             = "${var.project}-${var.env} s3 encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.project}-${var.env}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  processed_bucket = coalesce(var.processed_name, "${var.project}-${var.env}-processed-${random_id.suffix.hex}")
}

resource "aws_s3_bucket" "processed" {
  bucket        = local.processed_bucket
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket                = aws_s3_bucket.processed.id
  block_public_acls     = true
  block_public_policy   = true
  ignore_public_acls    = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ingest" {
  name               = "${var.project}-${var.env}-ingest-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "ingest_inline" {
  role = aws_iam_role.ingest.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:PutObject", "s3:AbortMultipartUpload"],
        Resource = ["${aws_s3_bucket.processed.arn}/*"]
      },
      {
        Effect   = "Allow",
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"],
        Resource = [aws_kms_key.s3.arn]
      },
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_lambda_function" "ingest" {
  function_name = "${var.project}-${var.env}-ingest"
  role          = aws_iam_role.ingest.arn
  runtime       = "python3.11"
  handler       = "ingest.lambda_handler"
  filename      = "${path.module}/lambda/ingest.zip"
  timeout       = 60
  environment {
    variables = {
      PROCESSED_BUCKET = aws_s3_bucket.processed.bucket
      TICKERS          = "SPY,AAPL,MSFT"
    }
  }
}

resource "aws_cloudwatch_event_rule" "daily" {
  name                = "${var.project}-${var.env}-daily"
  schedule_expression = "cron(0 1 * * ? *)"
}

resource "aws_cloudwatch_event_target" "daily_lambda" {
  rule      = aws_cloudwatch_event_rule.daily.name
  target_id = "ingest"
  arn       = aws_lambda_function.ingest.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily.arn
}