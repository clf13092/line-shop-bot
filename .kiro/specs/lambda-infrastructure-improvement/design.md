# 設計ドキュメント

## 概要

本設計では、LINE Bot（お店検索アシスタント）のインフラストラクチャをTerraformでコード化し、セキュリティを強化する。主な変更点は以下の3つ：

1. Terraformによるインフラ定義（Lambda、ECR、API Gateway、IAM）
2. Parameter Storeによるシークレット管理
3. API Gateway経由のセキュアなエンドポイント公開

## アーキテクチャ

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────┐
│  LINE Bot   │────▶│  API Gateway    │────▶│   Lambda    │
│  Webhook    │     │  (REST API)     │     │  (Container)│
└─────────────┘     └─────────────────┘     └──────┬──────┘
                                                   │
                    ┌─────────────────┐            │
                    │ Parameter Store │◀───────────┤
                    │ (SecureString)  │            │
                    └─────────────────┘            │
                                                   │
                    ┌─────────────────┐            │
                    │      ECR        │◀───────────┘
                    │ (Container Img) │
                    └─────────────────┘
```

## コンポーネントとインターフェース

### Terraformモジュール構成

```
terraform/
├── main.tf              # メインエントリポイント
├── variables.tf         # 入力変数定義
├── outputs.tf           # 出力値定義
├── providers.tf         # AWSプロバイダ設定
├── ecr.tf               # ECRリポジトリ
├── lambda.tf            # Lambda関数
├── api_gateway.tf       # API Gateway
├── iam.tf               # IAMロール・ポリシー
├── ssm.tf               # Parameter Store
└── environments/
    ├── dev.tfvars       # 開発環境変数
    ├── staging.tfvars   # ステージング環境変数
    └── prod.tfvars      # 本番環境変数
```

### コンポーネント詳細

#### 1. ECRリポジトリ (ecr.tf)

```hcl
resource "aws_ecr_repository" "line_bot" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "line_bot" {
  repository = aws_ecr_repository.line_bot.name
  
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "古いイメージを削除"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 14
      }
      action = {
        type = "expire"
      }
    }]
  })
}
```

#### 2. Lambda関数 (lambda.tf)

```hcl
resource "aws_lambda_function" "line_bot" {
  function_name = "${var.project_name}-${var.environment}"
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.line_bot.repository_url}:latest"
  
  timeout     = 60
  memory_size = 512
  
  environment {
    variables = {
      ENVIRONMENT        = var.environment
      SSM_PREFIX         = "/${var.project_name}/${var.environment}"
      REINIT_EVERY_SEC   = "900"
      LINE_MAX_TEXT_LEN  = "4500"
    }
  }
}
```

#### 3. API Gateway (api_gateway.tf)

```hcl
resource "aws_api_gateway_rest_api" "line_bot" {
  name        = "${var.project_name}-${var.environment}"
  description = "LINE Bot Webhook API"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "webhook" {
  rest_api_id = aws_api_gateway_rest_api.line_bot.id
  parent_id   = aws_api_gateway_rest_api.line_bot.root_resource_id
  path_part   = "webhook"
}

resource "aws_api_gateway_method" "webhook_post" {
  rest_api_id   = aws_api_gateway_rest_api.line_bot.id
  resource_id   = aws_api_gateway_resource.webhook.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.line_bot.id
  resource_id             = aws_api_gateway_resource.webhook.id
  http_method             = aws_api_gateway_method.webhook_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.line_bot.invoke_arn
}
```

#### 4. IAMロール (iam.tf)

```hcl
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
}

resource "aws_iam_role_policy" "ssm_read" {
  name = "ssm-read-policy"
  role = aws_iam_role.lambda_execution.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
    }]
  })
}
```

#### 5. Parameter Store (ssm.tf)

```hcl
resource "aws_ssm_parameter" "google_maps_api_key" {
  name        = "/${var.project_name}/${var.environment}/GOOGLE_MAPS_API_KEY"
  description = "Google Maps API Key"
  type        = "SecureString"
  value       = var.google_maps_api_key
  
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "channel_access_token" {
  name        = "/${var.project_name}/${var.environment}/CHANNEL_ACCESS_TOKEN"
  description = "LINE Channel Access Token"
  type        = "SecureString"
  value       = var.channel_access_token
  
  lifecycle {
    ignore_changes = [value]
  }
}
```

### アプリケーションコード修正

#### Parameter Store取得モジュール (secrets.py)

```python
import os
import boto3
from functools import lru_cache

_ssm_client = None
_secrets_cache = {}

def _get_ssm_client():
    global _ssm_client
    if _ssm_client is None:
        _ssm_client = boto3.client('ssm')
    return _ssm_client

def get_secret(name: str, use_cache: bool = True) -> str:
    """
    Parameter Storeからシークレットを取得する。
    環境変数SSM_PREFIXが設定されている場合はParameter Storeから取得。
    設定されていない場合は環境変数から取得（ローカルテスト用）。
    """
    ssm_prefix = os.environ.get("SSM_PREFIX")
    
    # ローカルテスト用：SSM_PREFIXがない場合は環境変数から取得
    if not ssm_prefix:
        return os.environ.get(name, "")
    
    # キャッシュチェック
    if use_cache and name in _secrets_cache:
        return _secrets_cache[name]
    
    # Parameter Storeから取得
    try:
        client = _get_ssm_client()
        param_name = f"{ssm_prefix}/{name}"
        response = client.get_parameter(Name=param_name, WithDecryption=True)
        value = response['Parameter']['Value']
        
        if use_cache:
            _secrets_cache[name] = value
        
        return value
    except Exception as e:
        print(f"[ERROR] Failed to get secret {name}: {e}")
        # フォールバック：環境変数から取得を試みる
        fallback = os.environ.get(name, "")
        if fallback:
            print(f"[WARN] Using environment variable fallback for {name}")
            return fallback
        raise RuntimeError(f"Secret {name} not found in Parameter Store or environment")

def clear_cache():
    """キャッシュをクリアする（テスト用）"""
    global _secrets_cache
    _secrets_cache = {}
```

## データモデル

### Terraform変数 (variables.tf)

```hcl
variable "project_name" {
  description = "プロジェクト名"
  type        = string
  default     = "line-shop-bot"
}

variable "environment" {
  description = "デプロイ環境 (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

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
```

## エラーハンドリング

### Parameter Store取得エラー

| エラー種別 | 原因 | 対応 |
|-----------|------|------|
| ParameterNotFound | パラメータが存在しない | 環境変数フォールバックを試行、なければRuntimeError |
| AccessDeniedException | IAM権限不足 | エラーログ出力、RuntimeError |
| ThrottlingException | API制限超過 | リトライ（boto3のデフォルトリトライで対応） |

### API Gateway関連エラー

| エラー種別 | 原因 | 対応 |
|-----------|------|------|
| 400 Bad Request | 不正なリクエストボディ | エラーレスポンス返却 |
| 500 Internal Server Error | Lambda内部エラー | エラーログ出力、エラーレスポンス返却 |
| 429 Too Many Requests | スロットリング | API Gatewayが自動で429を返却 |

### アプリケーションエラー

| エラー種別 | 原因 | 対応 |
|-----------|------|------|
| Agent初期化エラー | MCP接続失敗 | 強制再初期化してリトライ |
| LINE API エラー | トークン無効等 | エラーログ出力、処理継続 |

## テスト戦略

### テストアプローチ

本プロジェクトでは、ユニットテストを使用して主要な機能を検証する：

- **ユニットテスト**: 特定の例、エッジケース、エラー条件を検証

### Terraformテスト

```hcl
# terraform/tests/main.tftest.hcl
run "環境別リソース名テスト" {
  variables {
    environment = "dev"
    project_name = "line-shop-bot"
  }
  
  assert {
    condition     = aws_lambda_function.line_bot.function_name == "line-shop-bot-dev"
    error_message = "Lambda関数名に環境名が含まれていません"
  }
}
```

### Pythonユニットテスト

```python
# tests/test_secrets.py
import pytest
from unittest.mock import patch, MagicMock

def test_get_secret_from_ssm():
    """Parameter Storeからシークレットを取得できること"""
    with patch.dict('os.environ', {'SSM_PREFIX': '/test/dev'}):
        with patch('secrets.boto3.client') as mock_client:
            mock_ssm = MagicMock()
            mock_ssm.get_parameter.return_value = {
                'Parameter': {'Value': 'test-api-key'}
            }
            mock_client.return_value = mock_ssm
            
            from secrets import get_secret, clear_cache
            clear_cache()
            
            result = get_secret('GOOGLE_MAPS_API_KEY')
            assert result == 'test-api-key'

def test_get_secret_fallback_to_env():
    """SSM_PREFIXがない場合は環境変数から取得すること"""
    with patch.dict('os.environ', {'GOOGLE_MAPS_API_KEY': 'env-api-key'}, clear=True):
        from secrets import get_secret, clear_cache
        clear_cache()
        
        result = get_secret('GOOGLE_MAPS_API_KEY')
        assert result == 'env-api-key'

def test_get_secret_cache():
    """シークレットがキャッシュされること"""
    with patch.dict('os.environ', {'SSM_PREFIX': '/test/dev'}):
        with patch('secrets.boto3.client') as mock_client:
            mock_ssm = MagicMock()
            mock_ssm.get_parameter.return_value = {
                'Parameter': {'Value': 'cached-value'}
            }
            mock_client.return_value = mock_ssm
            
            from secrets import get_secret, clear_cache
            clear_cache()
            
            # 同じシークレットを3回取得
            get_secret('TEST_KEY')
            get_secret('TEST_KEY')
            get_secret('TEST_KEY')
            
            # SSMへのアクセスは1回のみ
            assert mock_ssm.get_parameter.call_count == 1

def test_get_secret_error_with_fallback():
    """SSM取得エラー時に環境変数フォールバックが動作すること"""
    with patch.dict('os.environ', {'SSM_PREFIX': '/test/dev', 'TEST_KEY': 'fallback-value'}):
        with patch('secrets.boto3.client') as mock_client:
            mock_ssm = MagicMock()
            mock_ssm.get_parameter.side_effect = Exception("SSM Error")
            mock_client.return_value = mock_ssm
            
            from secrets import get_secret, clear_cache
            clear_cache()
            
            result = get_secret('TEST_KEY')
            assert result == 'fallback-value'
```

### テスト実行コマンド

```bash
# Pythonユニットテスト
pytest tests/ -v

# Terraformテスト
cd terraform && terraform test
```

