# LINE Bot お店検索アシスタント

Google Maps APIを使用してお店を検索するLINE Botです。

## アーキテクチャ

```
LINE → API Gateway → Lambda → AgentCore Runtime → Memory
                                                 → Gateway → Google Maps API
```

## ディレクトリ構成

```
LINE_BOT/
├── lambda/           # LINE Webhook受付Lambda
│   ├── app.py
│   ├── ssm_secrets.py
│   ├── Dockerfile
│   └── requirements.txt
├── agentcore/        # AgentCore Runtimeプロジェクト
│   ├── src/main.py   # エージェント本体
│   └── ...
├── terraform/        # インフラ定義
└── .github/          # CI/CD
```

## 前提条件

- AWS CLI（認証設定済み）
- Terraform >= 1.0.0
- Docker
- Google Maps API Key
- LINE Channel Access Token

## デプロイ手順

### 1. AgentCore Runtimeのデプロイ

```bash
cd agentcore
source .venv/bin/activate
agentcore deploy --auto-update-on-conflict
```

### 2. Lambdaのデプロイ

```bash
# ECRリポジトリURLを取得
ECR_URL=$(terraform -chdir=terraform output -raw ecr_repository_url)

# ECRにログイン
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin $ECR_URL

# ビルド＆プッシュ
docker build --platform linux/amd64 -t line-shop-bot ./lambda
docker tag line-shop-bot:latest $ECR_URL:latest
docker push $ECR_URL:latest

# Lambda更新
aws lambda update-function-code \
  --function-name line-shop-bot-dev \
  --image-uri $ECR_URL:latest
```

### 3. Terraformでインフラ更新（必要時）

```bash
cd terraform
terraform apply -var-file=environments/dev.tfvars \
  -var="google_maps_api_key=$GOOGLE_MAPS_API_KEY" \
  -var="channel_access_token=$CHANNEL_ACCESS_TOKEN"
```

## 使い方

LINEで `@お店` に続けて条件を入力：

```
@お店 渋谷で静かなカフェ
@お店 新宿でデート向き居酒屋
```

1対1チャットでは `@お店` なしで直接入力可能。
