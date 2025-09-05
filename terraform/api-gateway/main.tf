resource "aws_api_gateway_rest_api" "terraform_sync" {
  name = "terraform-sync-api"
}

resource "aws_api_gateway_resource" "slack_actions" {
  rest_api_id = aws_api_gateway_rest_api.terraform_sync.id
  parent_id   = aws_api_gateway_rest_api.terraform_sync.root_resource_id
  path_part   = "slack-actions"
}

resource "aws_api_gateway_method" "slack_actions_post" {
  rest_api_id   = aws_api_gateway_rest_api.terraform_sync.id
  resource_id   = aws_api_gateway_resource.slack_actions.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "slack_actions_integration" {
  rest_api_id = aws_api_gateway_rest_api.terraform_sync.id
  resource_id = aws_api_gateway_resource.slack_actions.id
  http_method = aws_api_gateway_method.slack_actions_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${data.terraform_remote_state.lambda.outputs.action_handler_function_arn}/invocations"
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda.outputs.action_handler_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.terraform_sync.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "terraform_sync" {
  depends_on = [
    aws_api_gateway_method.slack_actions_post,
    aws_api_gateway_integration.slack_actions_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.terraform_sync.id
  stage_name  = "prod"
}