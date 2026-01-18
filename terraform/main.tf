# =============================================================================
# メインエントリポイント
# LINE Bot (お店検索アシスタント) Terraform構成
# =============================================================================

# -----------------------------------------------------------------------------
# データソース
# -----------------------------------------------------------------------------

# 現在のAWSアカウント情報を取得
data "aws_caller_identity" "current" {}

# 現在のAWSリージョン情報を取得
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# ローカル変数
# -----------------------------------------------------------------------------

locals {
  # 共通タグ（リソース識別用）
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # リソース名プレフィックス
  name_prefix = "${var.project_name}-${var.environment}"

  # Parameter Storeパスプレフィックス
  ssm_prefix = "/${var.project_name}/${var.environment}"

  # AWSアカウントID（IAMポリシー等で使用）
  account_id = data.aws_caller_identity.current.account_id

  # AWSリージョン
  region = data.aws_region.current.name
}
