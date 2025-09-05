#!/bin/bash

# S3 버킷 이름 가져오기
S3_BUCKET=$(cd terraform/s3 && terraform output -raw terraform_code_bucket_name)

echo "Uploading buildspec.yml to S3 bucket: $S3_BUCKET"

# buildspec.yml을 S3에 업로드
aws s3 cp buildspec.yml s3://$S3_BUCKET/buildspec.yml

echo "Upload completed!"