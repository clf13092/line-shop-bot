# =============================================================================
# 出力値定義
# =============================================================================

# API GatewayエンドポイントURL
output "api_gateway_endpoint_url" {
  description = "API Gateway webhook エンドポイントURL"
  value       = "${aws_api_gateway_stage.line_bot.invoke_url}/webhook"
}

# API Gateway REST API ID
output "api_gateway_rest_api_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.line_bot.id
}

# ECRリポジトリURL
output "ecr_repository_url" {
  description = "ECRリポジトリURL"
  value       = aws_ecr_repository.line_bot.repository_url
}

# ECRリポジトリ名
output "ecr_repository_name" {
  description = "ECRリポジトリ名"
  value       = aws_ecr_repository.line_bot.name
}

# Lambda関数ARN
output "lambda_function_arn" {
  description = "Lambda関数ARN"
  value       = aws_lambda_function.line_bot.arn
}

# Lambda関数名
output "lambda_function_name" {
  description = "Lambda関数名"
  value       = aws_lambda_function.line_bot.function_name
}
