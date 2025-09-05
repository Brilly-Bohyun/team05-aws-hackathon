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

resource "aws_api_gateway_method" "slack_actions_options" {
  rest_api_id   = aws_api_gateway_rest_api.terraform_sync.id
  resource_id   = aws_api_gateway_resource.slack_actions.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "slack_actions_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.terraform_sync.id
  resource_id = aws_api_gateway_resource.slack_actions.id
  http_method = aws_api_gateway_method.slack_actions_options.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "slack_actions_options_response" {
  rest_api_id = aws_api_gateway_rest_api.terraform_sync.id
  resource_id = aws_api_gateway_resource.slack_actions.id
  http_method = aws_api_gateway_method.slack_actions_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "slack_actions_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.terraform_sync.id
  resource_id = aws_api_gateway_resource.slack_actions.id
  http_method = aws_api_gateway_method.slack_actions_options.http_method
  status_code = aws_api_gateway_method_response.slack_actions_options_response.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_deployment" "terraform_sync" {
  depends_on = [
    aws_api_gateway_method.slack_actions_post,
    aws_api_gateway_integration.slack_actions_integration,
    aws_api_gateway_method.slack_actions_options,
    aws_api_gateway_integration.slack_actions_options_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.terraform_sync.id
  stage_name  = "prod"
}