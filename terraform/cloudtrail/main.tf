resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "terraform-sync-cloudtrail-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_policy" "cloudtrail_logs_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

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
  depends_on     = [aws_sns_topic_policy.cloudtrail_policy]
  name           = "terraform-sync-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs.bucket
  sns_topic_name = data.terraform_remote_state.sns_sqs.outputs.sns_topic_arn

  event_selector {
    read_write_type           = "WriteOnly"
    include_management_events = true
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}