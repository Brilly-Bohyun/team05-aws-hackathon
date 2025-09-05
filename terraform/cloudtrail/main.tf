resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "terraform-sync-cloudtrail-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  depends_on = [aws_s3_bucket_public_access_block.cloudtrail_logs]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:us-east-1:992382648368:trail/terraform-sync-trail"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:aws:cloudtrail:us-east-1:992382648368:trail/terraform-sync-trail"
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_policy" "cloudtrail_policy" {
  arn = data.terraform_remote_state.sns_sqs.outputs.sns_topic_arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailSNSPolicy"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = data.terraform_remote_state.sns_sqs.outputs.sns_topic_arn
      }
    ]
  })
}

resource "aws_cloudtrail" "terraform_sync" {
  depends_on                        = [aws_s3_bucket_policy.cloudtrail_logs_policy, aws_sns_topic_policy.cloudtrail_policy]
  name                              = "terraform-sync-trail"
  s3_bucket_name                    = aws_s3_bucket.cloudtrail_logs.bucket
  sns_topic_name                    = data.terraform_remote_state.sns_sqs.outputs.sns_topic_arn
  include_global_service_events     = true
  is_multi_region_trail            = true
  enable_logging                   = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}