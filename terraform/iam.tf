# =============================================================================
# IAMロール・ポリシー定義
# =============================================================================

# -----------------------------------------------------------------------------
# Lambda実行ロール
# -----------------------------------------------------------------------------

resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-lambda-role-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Logs基本実行ポリシー
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# -----------------------------------------------------------------------------
# Parameter Store読み取りポリシー
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ssm_read" {
  name = "${var.project_name}-ssm-read-policy-${var.environment}"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      Resource = "arn:aws:ssm:${local.region}:${local.account_id}:parameter${local.ssm_prefix}/*"
    }]
  })
}

# -----------------------------------------------------------------------------
# AgentCore Runtime呼び出しポリシー
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "agentcore_invoke" {
  name = "${var.project_name}-agentcore-invoke-policy-${var.environment}"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock-agentcore:InvokeAgentRuntime"
      ]
      Resource = "arn:aws:bedrock-agentcore:ap-northeast-1:${local.account_id}:runtime/*"
    }]
  })
}
