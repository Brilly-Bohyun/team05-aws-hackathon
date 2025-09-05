resource "aws_secretsmanager_secret" "github_token" {
  name = "github-token"
  description = "GitHub Personal Access Token for Terraform Sync"
}

resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id = aws_secretsmanager_secret.github_token.id
  secret_string = jsonencode({
    token = "your-github-token-here"
  })
  
  lifecycle {
    ignore_changes = [secret_string]
  }
}