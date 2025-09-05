resource "aws_s3_bucket" "test-rocket-10" {
  bucket = "test-rocket-10"
}

resource "aws_s3_bucket_versioning" "test-rocket-10" {
  bucket = aws_s3_bucket.test-rocket-10.id
  versioning_configuration {
    status = "Enabled"
  }
}
