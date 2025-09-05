resource "aws_s3_bucket" "test-rocket-9" {
  bucket = "test-rocket-9"
}

resource "aws_s3_bucket_versioning" "test-rocket-9" {
  bucket = aws_s3_bucket.test-rocket-9.id
  versioning_configuration {
    status = "Enabled"
  }
}
