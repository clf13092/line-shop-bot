# LINE Bot お店検索アシスタント

Google Maps APIを使用してお店を検索するLINE Botです。

## アーキテクチャ

```
LINE Bot → API Gateway → Lambda (Container) → Parameter Store
                                            → Google Maps API
```

## 前提条件

- AWS CLI（認証設定済み）
- Terraform >= 1.0.0
- Docker
- Google Maps API Key
- LINE Channel Access Token

## デプロイ手順

### 1. 環境変数の設定

```bash
export GOOGLE_MAPS_API_KEY="your-google-maps-api-key"
export CHANNEL_ACCESS_TOKEN="your-line-channel-access-token"
```

### 2. Terraformでインフラ構築（ECRのみ先に作成）

```bash
cd terraform

# 初期化（初回のみ）
terraform init

# ECRリポジトリを先に作成
terraform apply -var-file=environments/dev.tfvars \
  -var="google_maps_api_key=$GOOGLE_MAPS_API_KEY" \
  -var="channel_access_token=$CHANNEL_ACCESS_TOKEN" \
  -target=aws_ecr_repository.line_bot \
  -target=aws_ecr_lifecycle_policy.line_bot
```

### 3. Dockerイメージのビルド＆プッシュ

```bash
cd ..

# ECRリポジトリURLを取得
ECR_URL=$(terraform -chdir=terraform output -raw ecr_repository_url)

# ECRにログイン
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin $ECR_URL

# ビルド（Mac Apple Silicon対応）
docker build --platform linux/amd64 --provenance=false --sbom=false -t line-shop-bot .

# タグ付け＆プッシュ
docker tag line-shop-bot:latest $ECR_URL:latest
docker push $ECR_URL:latest
```

### 4. 残りのインフラを構築

```bash
cd terraform

terraform apply -var-file=environments/dev.tfvars \
  -var="google_maps_api_key=$GOOGLE_MAPS_API_KEY" \
  -var="channel_access_token=$CHANNEL_ACCESS_TOKEN"
```

### 5. LINE Webhook URLを設定

```bash
terraform output api_gateway_endpoint_url
```

出力されたURLをLINE Developers ConsoleのWebhook URLに設定。

## E2Eテスト

### curlでAPI Gatewayをテスト

```bash
# エンドポイントURLを取得
ENDPOINT=$(terraform -chdir=terraform output -raw api_gateway_endpoint_url)

# LINEのWebhookイベントをシミュレート
curl -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "events": [{
      "type": "message",
      "replyToken": "test-token",
      "source": {"type": "user", "userId": "test-user"},
      "message": {"type": "text", "text": "@お店 渋谷でカフェ"}
    }]
  }'
```

### Lambda関数を直接テスト

```bash
FUNCTION_NAME=$(terraform -chdir=terraform output -raw lambda_function_name)

aws lambda invoke \
  --function-name $FUNCTION_NAME \
  --payload '{"body": "{\"events\": []}"}' \
  --cli-binary-format raw-in-base64-out \
  response.json

cat response.json
```

### CloudWatch Logsで確認

```bash
# 最新のログを確認
aws logs tail /aws/lambda/line-shop-bot-dev --follow
```

## 使い方

LINEで `@お店` に続けて条件を入力：

```
@お店 渋谷で静かなカフェ
@お店 新宿でデート向き居酒屋
```

## 本番環境へのデプロイ

`dev.tfvars` を `prod.tfvars` に変更して同じ手順を実行。

## トラブルシューティング

### イメージプッシュエラー（Mac）

Apple Siliconでビルドする場合は必ず以下のオプションを付ける：
```bash
docker build --platform linux/amd64 --provenance=false --sbom=false -t line-shop-bot .
```
