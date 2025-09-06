# AWS Terraform 자동화 시스템 구축 대화 기록

## 프로젝트 개요
- **목표**: AWS 리소스 생성 시 자동으로 Terraform으로 관리하는 시스템 구축
- **아키텍처**: CloudTrail → SNS → SQS → Lambda → CodeBuild → Git 푸시

## 완성된 시스템 구성요소

### 1. 인프라 구성
- **Backend**: S3 + DynamoDB (Terraform State 관리)
- **S3**: CloudTrail 로그 및 Terraform 코드 저장
- **DynamoDB**: 이벤트 추적 테이블
- **SNS/SQS**: CloudTrail 이벤트 전달
- **Lambda**: 이벤트 처리 및 Slack 알림
- **API Gateway**: Slack 버튼 인터랙션
- **CodeBuild**: Terraform import 자동화

### 2. 주요 기능
- ✅ CloudTrail 이벤트 감지 (S3 버킷 생성 등)
- ✅ Slack 실시간 알림
- ✅ 버튼 클릭으로 리소스 삭제/Terraform 관리 선택
- ✅ CodeBuild를 통한 자동 Terraform import
- ✅ GitHub 자동 푸시 (충돌 방지 로직 포함)

### 3. 완전 자동화 흐름
1. AWS 콘솔에서 S3 버킷 생성
2. CloudTrail → SNS → SQS → Lambda 감지
3. Slack 알림 전송 (리소스 정보 포함)
4. 사용자가 "Terraform으로 관리" 버튼 클릭
5. CodeBuild 자동 실행:
   - Terraform 코드 생성
   - `terraform import` 실행
   - State 파일 업데이트
   - GitHub에 자동 푸시

## 기술적 해결 과제들

### 1. CloudTrail 이벤트 파싱
- **문제**: SNS 메시지에 S3 파일 경로만 포함
- **해결**: Lambda에서 S3 파일 다운로드 후 gzip 압축 해제하여 실제 이벤트 파싱

### 2. Slack 인터랙션
- **문제**: form-urlencoded 데이터 파싱 오류
- **해결**: `urllib.parse.parse_qs()` 사용하여 올바른 파싱

### 3. CodeBuild YAML 구문
- **문제**: buildspec.yml 멀티라인 명령어 구문 오류
- **해결**: YAML 멀티라인 블록(`|`) 사용

### 4. Terraform Import 실패
- **문제**: 환경변수 참조 및 파일 경로 문제
- **해결**: 루트 디렉토리에 파일 생성, 올바른 변수 참조

## 최종 디렉토리 구조
```
terraform/
├── backend/       # S3 + DynamoDB 백엔드
├── s3/            # S3 버킷 리소스
├── dynamodb/      # DynamoDB 테이블
├── sns-sqs/       # SNS + SQS 설정
├── lambda/        # Lambda 함수들
├── api-gateway/   # API Gateway 설정
└── codebuild/     # CodeBuild 프로젝트
```

## Git 레포지토리
- **URL**: https://github.com/Brilly-Bohyun/team05-aws-hackathon
- **자동 푸시**: CodeBuild에서 충돌 방지 로직과 함께 자동 커밋/푸시

## 성과
- 🎉 **완전 자동화**: 수동 개입 없이 AWS 리소스 → Terraform 관리 전환
- 🔒 **충돌 방지**: Git pull/rebase를 통한 안전한 푸시
- 📊 **실시간 알림**: Slack을 통한 즉시 알림 및 액션
- 🏗️ **확장 가능**: 다른 AWS 리소스 타입으로 쉽게 확장 가능

---
*생성일: 2025-09-05*
*프로젝트: team05-aws-hackathon*