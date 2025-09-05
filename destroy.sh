#!/bin/bash

set -e

echo "🗑️ Terraform State 동기화 서비스 리소스 삭제 시작..."

# 삭제 순서 (배포의 역순)
DESTROY_ORDER=(
    "api-gateway"
    "lambda"
    "cloudtrail"
    "sns-sqs"
    "dynamodb"
    "s3"
    "backend"
)

for dir in "${DESTROY_ORDER[@]}"; do
    echo "🗑️ $dir 삭제 중..."
    cd "terraform/$dir"
    terraform destroy -auto-approve
    cd ../..
    echo "✅ $dir 삭제 완료"
done

echo "🎉 모든 리소스 삭제가 완료되었습니다!"