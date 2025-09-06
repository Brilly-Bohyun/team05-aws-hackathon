resource "aws_s3_bucket" "test-rocket-14" {
  bucket = "test-rocket-14"
}

resource "aws_s3_bucket_versioning" "test-rocket-14" {
  bucket = aws_s3_bucket.test-rocket-14.id
  versioning_configuration {
    status = "Enabled"
  }
}
