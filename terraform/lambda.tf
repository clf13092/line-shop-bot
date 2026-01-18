# =============================================================================
# Lambda関数定義
# =============================================================================

resource "aws_lambda_function" "line_bot" {
  function_name = "${var.project_name}-${var.environment}"
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.line_bot.repository_url}:latest"

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      ENVIRONMENT       = var.environment
      SSM_PREFIX        = "/${var.project_name}/${var.environment}"
      REINIT_EVERY_SEC  = "900"
      LINE_MAX_TEXT_LEN = "4500"
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}
