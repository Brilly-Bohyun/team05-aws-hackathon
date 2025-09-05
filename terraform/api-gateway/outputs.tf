output "api_gateway_url" {
  value = "${aws_api_gateway_deployment.terraform_sync.invoke_url}/slack-actions"
  description = "Slack Interactive Components에 등록할 URL"
}