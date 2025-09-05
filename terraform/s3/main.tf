resource "aws_s3_bucket" "terraform_code" {
  bucket = "terraform-sync-code-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_versioning" "terraform_code" {
  bucket = aws_s3_bucket.terraform_code.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_code" {
  bucket = aws_s3_bucket.terraform_code.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_code" {
  bucket = aws_s3_bucket.terraform_code.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}