# Git 푸시 설정 가이드

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

## 3. Git 레포지토리 URL 수정

`terraform/lambda/src/action_handler.py`에서 실제 레포지토리 URL로 변경:

```python
{
    'name': 'GIT_REPO_URL',
    'value': 'https://github.com/Brilly-Bohyun/team05-aws-hackathon.git'
}
```

## 4. buildspec.yml에서 레포지토리 URL 수정

`buildspec.yml`에서 실제 레포지토리 URL로 변경:

```yaml
- git clone https://$GITHUB_TOKEN@github.com/Brilly-Bohyun/team05-aws-hackathon.git /tmp/git-repo
```

## 5. 배포

```bash
cd terraform/codebuild
terraform apply -auto-approve

cd ../lambda
terraform taint aws_lambda_function.action_handler
terraform apply -auto-approve
```

## 완성된 흐름

1. **S3 버킷 생성** → Slack 알림
2. **"Terraform으로 관리" 클릭** → CodeBuild 시작
3. **CodeBuild 실행**:
   - Terraform import
   - State 업데이트
   - S3에 파일 저장
   - **Git에 자동 푸시** ✅
4. **결과**: https://github.com/Brilly-Bohyun/team05-aws-hackathon 레포지토리에 새 Terraform 파일 커밋됨