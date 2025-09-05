resource "aws_s3_bucket" "test-rocket-7" {
  bucket = "test-rocket-7"
}

resource "aws_s3_bucket_versioning" "test-rocket-7" {
  bucket = aws_s3_bucket.test-rocket-7.id
  versioning_configuration {
    status = "Enabled"
  }
}
