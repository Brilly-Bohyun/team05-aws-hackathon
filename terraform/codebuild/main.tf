resource "aws_iam_role" "codebuild_role" {
  name = "terraform-sync-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "terraform-sync-codebuild-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${data.terraform_remote_state.s3.outputs.terraform_code_bucket_name}",
          "arn:aws:s3:::${data.terraform_remote_state.s3.outputs.terraform_code_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "s3:*",
          "rds:*",
          "lambda:*",
          "dynamodb:*",
          "iam:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:us-east-1:*:secret:github-token-*"
      }
    ]
  })
}

resource "aws_codebuild_project" "terraform_import" {
  name          = "terraform-sync-import"
  description   = "Terraform import and state synchronization"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type = "NO_SOURCE"
    buildspec = <<EOF
version: 0.2
phases:
  install:
    runtime-versions:
      python: 3.9
    commands:
      - echo "Installing Terraform..."
      - wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
      - unzip terraform_1.5.0_linux_amd64.zip
      - mv terraform /usr/local/bin/
      - terraform version
  pre_build:
    commands:
      - echo "Setting up Terraform workspace..."
      - mkdir -p /tmp/terraform-workspace
      - cd /tmp/terraform-workspace
      - echo "Creating Terraform configuration..."
      - echo "$TERRAFORM_CODE" > $RESOURCE_NAME.tf
      - echo "Creating provider configuration..."
      - |
        cat > provider.tf << 'PROVIDER_EOF'
        terraform {
          required_version = ">= 1.0"
          required_providers {
            aws = {
              source  = "hashicorp/aws"
              version = "~> 5.0"
            }
          }
          backend "s3" {
            bucket         = "terraform-sync-state-6395e36ea95d48ee"
            key            = "s3_bucket/terraform.tfstate"
            region         = "us-east-1"
            dynamodb_table = "terraform-sync-locks"
          }
        }
        provider "aws" {
          region = "us-east-1"
        }
        PROVIDER_EOF
  build:
    commands:
      - echo "Initializing Terraform..."
      - terraform init
      - echo "Importing resource to Terraform state..."
      - |
        echo "Environment variables:"
        echo "RESOURCE_TYPE=$RESOURCE_TYPE"
        echo "RESOURCE_NAME=$RESOURCE_NAME"
        echo "RESOURCE_ID=$RESOURCE_ID"
        echo "Import command: terraform import aws_$RESOURCE_TYPE.$RESOURCE_NAME $RESOURCE_ID"
      - terraform import aws_$RESOURCE_TYPE.$RESOURCE_NAME $RESOURCE_ID
      - echo "Running terraform plan..."
      - terraform plan
      - echo "Applying Terraform configuration..."
      - terraform apply -auto-approve
  post_build:
    commands:
      - echo "Getting GitHub token from Secrets Manager..."
      - export GITHUB_TOKEN=$(aws secretsmanager get-secret-value --secret-id github-token --query SecretString --output text | jq -r .token)
      - echo "Cloning Git repository..."
      - git clone https://$GITHUB_TOKEN@github.com/Brilly-Bohyun/team05-aws-hackathon.git /tmp/git-repo
      - cd /tmp/git-repo
      - echo "Configuring Git..."
      - git config user.name "Terraform Sync Bot"
      - git config user.email "terraform-sync@company.com"
      - echo "Pulling latest changes..."
      - git pull origin main
      - echo "Copying Terraform files to Git repository..."
      - mkdir -p terraform/$RESOURCE_TYPE
      - cp /tmp/terraform-workspace/$RESOURCE_NAME.tf terraform/$RESOURCE_TYPE/
      - echo "Adding files to Git..."
      - git add terraform/$RESOURCE_TYPE/$RESOURCE_NAME.tf
      - echo "Committing changes..."
      - git commit -m "feat Import $RESOURCE_TYPE resource $RESOURCE_NAME to Terraform" || echo "No changes to commit"
      - echo "Pulling latest changes before push..."
      - git pull --rebase origin main
      - echo "Pushing to Git repository..."
      - git push origin main
      - echo "Terraform import completed successfully!"
EOF
  }
}