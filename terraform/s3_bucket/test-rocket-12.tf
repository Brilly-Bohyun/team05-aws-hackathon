resource "aws_s3_bucket" "test-rocket-12" {
  bucket = "test-rocket-12"
}

resource "aws_s3_bucket_versioning" "test-rocket-12" {
  bucket = aws_s3_bucket.test-rocket-12.id
  versioning_configuration {
    status = "Enabled"
  }
}
