# =============================================================================
# API Gateway REST API定義
# =============================================================================

resource "aws_api_gateway_rest_api" "line_bot" {
  name        = "${var.project_name}-${var.environment}"
  description = "LINE Bot Webhook API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# =============================================================================
# /webhook リソース
# =============================================================================

resource "aws_api_gateway_resource" "webhook" {
  rest_api_id = aws_api_gateway_rest_api.line_bot.id
  parent_id   = aws_api_gateway_rest_api.line_bot.root_resource_id
  path_part   = "webhook"
}

# =============================================================================
# POST メソッド
# =============================================================================

resource "aws_api_gateway_method" "webhook_post" {
  rest_api_id   = aws_api_gateway_rest_api.line_bot.id
  resource_id   = aws_api_gateway_resource.webhook.id
  http_method   = "POST"
  authorization = "NONE"
}

# =============================================================================
# Lambda プロキシ統合
# =============================================================================

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.line_bot.id
  resource_id             = aws_api_gateway_resource.webhook.id
  http_method             = aws_api_gateway_method.webhook_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.line_bot.invoke_arn
}


# =============================================================================
# デプロイメント
# =============================================================================

resource "aws_api_gateway_deployment" "line_bot" {
  rest_api_id = aws_api_gateway_rest_api.line_bot.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.webhook.id,
      aws_api_gateway_method.webhook_post.id,
      aws_api_gateway_integration.lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.webhook_post,
    aws_api_gateway_integration.lambda,
  ]
}

# =============================================================================
# ステージ（スロットリング設定付き）
# =============================================================================

resource "aws_api_gateway_stage" "line_bot" {
  deployment_id = aws_api_gateway_deployment.line_bot.id
  rest_api_id   = aws_api_gateway_rest_api.line_bot.id
  stage_name    = var.environment

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId         = "$context.requestId"
      ip                = "$context.identity.sourceIp"
      caller            = "$context.identity.caller"
      user              = "$context.identity.user"
      requestTime       = "$context.requestTime"
      httpMethod        = "$context.httpMethod"
      resourcePath      = "$context.resourcePath"
      status            = "$context.status"
      protocol          = "$context.protocol"
      responseLength    = "$context.responseLength"
      integrationStatus = "$context.integrationStatus"
    })
  }

  depends_on = [aws_api_gateway_account.main]

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.line_bot.id
  stage_name  = aws_api_gateway_stage.line_bot.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = var.api_gateway_throttle_rate_limit
    throttling_burst_limit = var.api_gateway_throttle_burst_limit
    logging_level          = "INFO"
    data_trace_enabled     = true
    metrics_enabled        = true
  }
}


# =============================================================================
# CloudWatch ログ設定
# =============================================================================

# API Gateway用CloudWatch Logsロググループ
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/api-gateway/${var.project_name}-${var.environment}"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-gateway-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# API Gateway用IAMロール（CloudWatch Logs書き込み用）
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.project_name}-api-gateway-cloudwatch-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-api-gateway-cloudwatch-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch" {
  name = "cloudwatch-logs-policy"
  role = aws_iam_role.api_gateway_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ]
      Resource = "*"
    }]
  })
}

# API Gatewayアカウント設定（CloudWatch Logsロール）
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}


# =============================================================================
# Lambda実行権限（API GatewayからLambdaを呼び出す権限）
# =============================================================================

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.line_bot.function_name
  principal     = "apigateway.amazonaws.com"

  # /*/*はすべてのステージとメソッドを許可
  source_arn = "${aws_api_gateway_rest_api.line_bot.execution_arn}/*/*"
}
