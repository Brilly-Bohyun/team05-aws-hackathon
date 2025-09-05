# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "terraform-sync-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "terraform-sync-lambda-policy"
  role = aws_iam_role.lambda_role.id

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
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = data.terraform_remote_state.sns_sqs.outputs.sqs_queue_arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:us-east-1:*:table/${data.terraform_remote_state.dynamodb.outputs.events_table_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${data.terraform_remote_state.s3.outputs.terraform_code_bucket_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "s3:*",
          "rds:*",
          "lambda:*",
          "dynamodb:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ]
        Resource = "*"
      }
    ]
  })
}

# Event Processor Lambda
data "archive_file" "event_processor_zip" {
  type        = "zip"
  output_path = "/tmp/event_processor.zip"
  source {
    content = templatefile("${path.module}/src/event_processor.py", {
      dynamodb_table = data.terraform_remote_state.dynamodb.outputs.events_table_name
      slack_webhook_url = var.slack_webhook_url
    })
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "event_processor" {
  filename         = data.archive_file.event_processor_zip.output_path
  function_name    = "terraform-sync-event-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      DYNAMODB_TABLE = data.terraform_remote_state.dynamodb.outputs.events_table_name
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = data.terraform_remote_state.sns_sqs.outputs.sqs_queue_arn
  function_name    = aws_lambda_function.event_processor.arn
  batch_size       = 1
}

# Action Handler Lambda
data "archive_file" "action_handler_zip" {
  type        = "zip"
  output_path = "/tmp/action_handler.zip"
  source {
    content = templatefile("${path.module}/src/action_handler.py", {
      dynamodb_table = data.terraform_remote_state.dynamodb.outputs.events_table_name
      s3_bucket = data.terraform_remote_state.s3.outputs.terraform_code_bucket_name
    })
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "action_handler" {
  filename         = data.archive_file.action_handler_zip.output_path
  function_name    = "terraform-sync-action-handler"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 900

  environment {
    variables = {
      DYNAMODB_TABLE = data.terraform_remote_state.dynamodb.outputs.events_table_name
      S3_BUCKET = data.terraform_remote_state.s3.outputs.terraform_code_bucket_name
    }
  }
}