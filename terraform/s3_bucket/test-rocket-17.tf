resource "aws_s3_bucket" "test-rocket-17" {
  bucket = "test-rocket-17"
}

resource "aws_s3_bucket_versioning" "test-rocket-17" {
  bucket = aws_s3_bucket.test-rocket-17.id
  versioning_configuration {
    status = "Enabled"
  }
}
