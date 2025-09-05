output "event_processor_function_name" {
  value = aws_lambda_function.event_processor.function_name
}

output "action_handler_function_name" {
  value = aws_lambda_function.action_handler.function_name
}

output "action_handler_function_arn" {
  value = aws_lambda_function.action_handler.arn
}