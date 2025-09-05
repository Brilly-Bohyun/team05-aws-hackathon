resource "aws_sns_topic" "cloudtrail_events" {
  name = "terraform-sync-cloudtrail-events"
}

resource "aws_sqs_queue" "event_queue" {
  name                      = "terraform-sync-event-queue"
  message_retention_seconds = 1209600
  visibility_timeout_seconds = 300
}

resource "aws_sqs_queue_policy" "event_queue_policy" {
  queue_url = aws_sqs_queue.event_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.event_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.cloudtrail_events.arn
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "sqs_subscription" {
  topic_arn = aws_sns_topic.cloudtrail_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.event_queue.arn
}