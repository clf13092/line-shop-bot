# =============================================================================
# GitHub Actions OIDC認証用リソース
# =============================================================================

# -----------------------------------------------------------------------------
# 変数
# -----------------------------------------------------------------------------

variable "github_repository" {
  description = "GitHubリポジトリ名 (owner/repo形式)"
  type        = string
  default     = "clf13092/line-shop-bot"
}

# -----------------------------------------------------------------------------
# GitHub OIDC Provider
# -----------------------------------------------------------------------------

data "aws_iam_openid_connect_provider" "github" {
  count = var.environment == "dev" ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.environment == "dev" && length(data.aws_iam_openid_connect_provider.github) == 0 ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name        = "github-actions-oidc"
    Environment = var.environment
    Project     = var.project_name
  }
}

locals {
  github_oidc_provider_arn = var.environment == "dev" ? (
    length(data.aws_iam_openid_connect_provider.github) > 0
    ? data.aws_iam_openid_connect_provider.github[0].arn
    : aws_iam_openid_connect_provider.github[0].arn
  ) : ""
}

# -----------------------------------------------------------------------------
# GitHub Actions用IAMロール
# -----------------------------------------------------------------------------

resource "aws_iam_role" "github_actions" {
  count = var.environment == "dev" ? 1 : 0

  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.github_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-github-actions-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# -----------------------------------------------------------------------------
# ECRプッシュ権限
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "github_actions_ecr" {
  count = var.environment == "dev" ? 1 : 0

  name = "${var.project_name}-github-actions-ecr-policy"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = aws_ecr_repository.line_bot.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Lambda更新権限
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "github_actions_lambda" {
  count = var.environment == "dev" ? 1 : 0

  name = "${var.project_name}-github-actions-lambda-policy"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "lambda:UpdateFunctionCode",
        "lambda:GetFunction"
      ]
      Resource = aws_lambda_function.line_bot.arn
    }]
  })
}

# -----------------------------------------------------------------------------
# SSM Parameter Store読み取り権限（Terraform用）
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "github_actions_ssm" {
  count = var.environment == "dev" ? 1 : 0

  name = "${var.project_name}-github-actions-ssm-policy"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      Resource = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/${var.project_name}/*"
    }]
  })
}

# -----------------------------------------------------------------------------
# Terraform実行権限
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "github_actions_terraform" {
  count = var.environment == "dev" ? 1 : 0

  name = "${var.project_name}-github-actions-terraform-policy"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PassRole",
          "iam:TagRole",
          "iam:GetOpenIDConnectProvider"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:*"
        ]
        Resource = "arn:aws:lambda:${local.region}:${local.account_id}:function:${var.project_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:*"
        ]
        Resource = "arn:aws:ecr:${local.region}:${local.account_id}:repository/${var.project_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:*"
        ]
        Resource = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/${var.project_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "apigateway:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:*"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${var.project_name}-*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# AgentCore Runtime デプロイ権限
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "github_actions_agentcore" {
  count = var.environment == "dev" ? 1 : 0

  name = "${var.project_name}-github-actions-agentcore-policy"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock-agentcore:*"
      ]
      Resource = "*"
    }]
  })
}

# -----------------------------------------------------------------------------
# 出力
# -----------------------------------------------------------------------------

output "github_actions_role_arn" {
  description = "GitHub Actions用IAMロールARN"
  value       = var.environment == "dev" ? aws_iam_role.github_actions[0].arn : ""
}
