resource "aws_s3_bucket" "test-rocket-13" {
  bucket = "test-rocket-13"
}

resource "aws_s3_bucket_versioning" "test-rocket-13" {
  bucket = aws_s3_bucket.test-rocket-13.id
  versioning_configuration {
    status = "Enabled"
  }
}
