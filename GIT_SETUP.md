# Git 자동 동기화 설정 가이드

## 1. GitHub Personal Access Token 생성

1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. "Generate new token" 클릭
3. 권한 선택:
   - `repo` (전체 저장소 액세스)
   - `workflow` (GitHub Actions 워크플로우)
4. 토큰 복사

## 2. AWS Secrets Manager에 토큰 저장

```bash
aws secretsmanager put-secret-value \
  --secret-id github-token \
  --secret-string '{"token":"your-github-token-here"}' \
  --region us-east-1
```

## 3. CodeBuild 프로젝트 배포

```bash
cd terraform/codebuild
terraform init
terraform apply -auto-approve
```

## 4. 시스템 테스트

1. AWS 콘솔에서 S3 버킷 생성 (예: `test-bucket-123`)
2. CodeBuild 프로젝트 수동 실행:
   ```bash
   aws codebuild start-build \
     --project-name terraform-sync-import \
     --environment-variables-override \
       name=RESOURCE_TYPE,value=s3_bucket \
       name=RESOURCE_NAME,value=test-bucket-123 \
       name=RESOURCE_ID,value=test-bucket-123 \
       name=TERRAFORM_CODE,value='resource "aws_s3_bucket" "test-bucket-123" { bucket = "test-bucket-123" }'
   ```
3. Git 레포지토리에서 새로운 파일 확인: `terraform/s3_bucket/test-bucket-123.tf`

## 완성된 자동화 흐름

1. **AWS 콘솔에서 리소스 생성** (예: S3 버킷)
2. **CloudTrail 이벤트 감지** → SNS → SQS → Lambda
3. **Slack 알림 전송** ("Terraform으로 관리" 버튼 포함)
4. **사용자가 버튼 클릭** → API Gateway → Lambda
5. **CodeBuild 자동 실행**:
   - 원격 Terraform State 사용 (`terraform-sync-state-6395e36ea95d48ee` S3 버킷)
   - `terraform import` 실행
   - 리소스를 State에 추가
   - **Git에 자동 커밋 및 푸시** ✅
6. **결과**: 
   - 원격 State 업데이트됨
   - Git 레포지토리에 새 Terraform 파일 추가됨
   - 팀원들이 `terraform plan` 실행 시 동기화된 State 확인 가능

## 주요 특징

- **원격 State 공유**: 모든 팀원이 동일한 S3 backend 사용
- **자동 Git 동기화**: CodeBuild에서 자동으로 커밋 및 푸시
- **State 일관성**: 로컬과 원격 State 완전 동기화