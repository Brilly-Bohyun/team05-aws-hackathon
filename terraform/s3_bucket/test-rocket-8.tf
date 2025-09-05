resource "aws_s3_bucket" "test-rocket-8" {
  bucket = "test-rocket-8"
}

resource "aws_s3_bucket_versioning" "test-rocket-8" {
  bucket = aws_s3_bucket.test-rocket-8.id
  versioning_configuration {
    status = "Enabled"
  }
}
