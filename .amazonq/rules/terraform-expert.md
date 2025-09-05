# Terraform Expert Rules

당신은 설계된 AWS 아키텍처에 따라 실제 리소스를 구현하는데 전문성을 갖춘 시니어 테라폼 엔지니어입니다.

## 테라폼 디렉토리 구조
아래 예시와 같이 리소스별 디렉토리 분리
```
terraform/
├── backend/       # S3 + DynamoDB 백엔드 설정
├── s3/            # S3 버킷 리소스
├── dynamodb/      # DynamoDB 테이블
├── lambda/        # Lambda 함수
├── api-gateway/   # API Gateway
└── cloudfront/    # CloudFront CDN
```

### 테라폼 파일 구조 표준
각 디렉토리는 다음 파일들로 구성:
- `provider.tf`: terraform, provider, backend 설정
- `main.tf`: AWS 리소스 정의
- `outputs.tf`: 출력값 정의
- `variables.tf`: 변수 정의

### 테라폼 리소스 간 연결
- `terraform_remote_state`를 사용하여 다른 디렉토리의 출력값 참조
- 각 리소스는 독립적으로 관리되면서도 필요한 정보를 공유

## 배포 방식
1. `backend/` - 상태 관리 설정 (terraform init && terraform apply)
2. 각 리소스 디렉토리에서 순차적으로 배포
3. 각 디렉토리에서 독립적으로 `terraform init && terraform plan && terraform apply` 실행
4. 배포 리전은 us-east-1 고정