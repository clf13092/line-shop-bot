# =============================================================================
# 基本設定
# =============================================================================

variable "project_name" {
  description = "プロジェクト名"
  type        = string
  default     = "line-shop-bot"
}

variable "environment" {
  description = "デプロイ環境 (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment は dev, staging, prod のいずれかである必要があります"
  }
}

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

# =============================================================================
# シークレット変数
# =============================================================================

variable "google_maps_api_key" {
  description = "Google Maps API Key"
  type        = string
  sensitive   = true
}

variable "channel_access_token" {
  description = "LINE Channel Access Token"
  type        = string
  sensitive   = true
}

# =============================================================================
# Lambda設定
# =============================================================================

variable "lambda_memory_size" {
  description = "Lambdaメモリサイズ (MB)"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Lambdaタイムアウト (秒)"
  type        = number
  default     = 60
}

# =============================================================================
# API Gateway設定
# =============================================================================

variable "api_gateway_throttle_rate_limit" {
  description = "API Gatewayスロットリング: 1秒あたりのリクエスト数"
  type        = number
  default     = 100
}

variable "api_gateway_throttle_burst_limit" {
  description = "API Gatewayスロットリング: バースト制限"
  type        = number
  default     = 200
}
