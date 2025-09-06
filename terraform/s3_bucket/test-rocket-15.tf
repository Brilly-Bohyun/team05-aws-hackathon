resource "aws_s3_bucket" "test-rocket-15" {
  bucket = "test-rocket-15"
}

resource "aws_s3_bucket_versioning" "test-rocket-15" {
  bucket = aws_s3_bucket.test-rocket-15.id
  versioning_configuration {
    status = "Enabled"
  }
}
