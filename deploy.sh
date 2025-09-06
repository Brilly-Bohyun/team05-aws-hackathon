#!/bin/bash

set -e

echo "🚀 Terraform State 동기화 서비스 배포 시작..."

# 배포 순서
DEPLOY_ORDER=(
    "backend"
    "s3"
    "dynamodb"
    "sns-sqs"
    "cloudtrail"
    "lambda"
    "api-gateway"
    "codebuild"
)

for dir in "${DEPLOY_ORDER[@]}"; do
    echo "📦 $dir 배포 중..."
    cd "terraform/$dir"
    terraform init
    terraform plan
    terraform apply -auto-approve
    cd ../..
    echo "✅ $dir 배포 완료"
done

echo "🎉 모든 리소스 배포가 완료되었습니다!"
echo "📋 다음 단계:"
echo "1. AWS 콘솔에서 S3 버킷 생성 후 CodeBuild 트리거"
echo "2. 생성된 리소스가 Git에 자동 커밋되는지 확인"
echo "3. terraform/s3_bucket 디렉토리에서 terraform plan 실행하여 동기화 확인"