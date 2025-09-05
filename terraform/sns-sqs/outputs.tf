output "sns_topic_arn" {
  value = aws_sns_topic.cloudtrail_events.arn
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.event_queue.arn
}

output "sqs_queue_url" {
  value = aws_sqs_queue.event_queue.url
}