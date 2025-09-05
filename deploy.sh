#!/bin/bash

set -e

echo "🚀 Terraform State 동기화 서비스 배포 시작..."

# 환경 변수 확인
if [ -z "$SLACK_WEBHOOK_URL" ]; then
    echo "❌ SLACK_WEBHOOK_URL 환경 변수가 설정되지 않았습니다."
    echo "export SLACK_WEBHOOK_URL=\"https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK\""
    exit 1
fi

# 배포 순서
DEPLOY_ORDER=(
    "backend"
    "s3"
    "dynamodb"
    "sns-sqs"
    "cloudtrail"
    "lambda"
    "api-gateway"
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
echo "1. API Gateway URL을 Slack App의 Interactive Components에 등록"
echo "2. AWS 콘솔에서 리소스를 생성하여 테스트"