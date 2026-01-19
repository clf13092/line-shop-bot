# LINEで「@お店」と送るだけ！AIがお店を探してくれるBotを作った

## はじめに

「渋谷で静かなカフェ探して」「新宿でデート向きの居酒屋ある？」

こんな風にLINEで聞くだけで、AIがGoogle Mapsから条件に合うお店を探して提案してくれるBotを作りました。

📸 **[スクショ: LINEでの実際の会話画面]**

## どんなサービス？

### 使い方はシンプル

LINEで `@お店` に続けて条件を入力するだけ。

```
@お店 渋谷で静かなカフェ
@お店 上野で3000円以下の焼肉
@お店 品川駅近くでランチ
```

📸 **[スクショ: 様々な検索例と結果]**

### 返ってくる情報

- 店名
- 距離（目安）
- 価格帯（目安）
- おすすめポイント
- Google Mapsへのリンク

さらに「もっと絞り込む質問」も提案してくれるので、会話しながら理想のお店を見つけられます。

📸 **[スクショ: 詳細な検索結果の例]**

---

## 技術構成

### アーキテクチャ図

📸 **[画像: generated-diagrams/line-bot-architecture.png]**

### 使用技術

| カテゴリ | 技術 |
|---------|------|
| AI/LLM | Amazon Bedrock (Claude) |
| 地図API | Google Maps API (MCP Server) |
| コンピュート | AWS Lambda (コンテナ) |
| API | Amazon API Gateway |
| シークレット管理 | AWS Systems Manager Parameter Store |
| IaC | Terraform |
| 言語 | Python 3.12 |

### 処理フロー

```
1. ユーザーがLINEで「@お店 渋谷でカフェ」と送信
2. LINE PlatformがWebhookでAPI Gatewayを呼び出し
3. API GatewayがLambda関数を起動
4. Lambdaが「検索中です」と即レス（reply）
5. Bedrock (Claude) がユーザーの意図を解析
6. Google Maps APIで条件に合うお店を検索
7. Claudeが結果を整形して返答を生成
8. LINEにプッシュメッセージで結果を送信
```

📸 **[スクショ: CloudWatch Logsでの処理フロー]**

---

## こだわりポイント

### 1. 即レス + 結果は後から

お店検索には数秒かかるため、まず「検索中です」と即レスして、結果は後からプッシュメッセージで送信。ユーザーを待たせない工夫です。

```python
# ① まず即レス
send_line_reply(reply_token, "ただいま条件に合うお店をお探ししております...")

# ② 重い処理（AI + Google Maps）
ai_response = _call_agent(query)

# ③ 結果はpushで送信
send_line_push(dest, ai_response, CHANNEL_ACCESS_TOKEN)
```

### 2. グループチャット対応

個人チャットだけでなく、グループやトークルームでも使えます。

```python
def _get_push_destination(ev):
    source = ev.get("source", {})
    source_type = source.get("type")
    
    if source_type == "user":
        return source.get("userId")
    if source_type == "group":
        return source.get("groupId")
    if source_type == "room":
        return source.get("roomId")
```

📸 **[スクショ: グループチャットでの使用例]**

### 3. セキュアなシークレット管理

APIキーやトークンは環境変数ではなく、AWS Parameter Store（SecureString）で管理。

```python
def get_secret(name: str) -> str:
    ssm_prefix = os.environ.get("SSM_PREFIX")
    client = boto3.client('ssm')
    response = client.get_parameter(
        Name=f"{ssm_prefix}/{name}", 
        WithDecryption=True
    )
    return response['Parameter']['Value']
```

📸 **[スクショ: AWSコンソールのParameter Store画面]**

### 4. エラー時の自動リトライ

AI接続が失敗した場合、自動で再初期化してリトライ。

```python
try:
    ai_response = _call_agent(query)
except Exception:
    # 強制再初期化してリトライ
    _ensure_agent_ready(force_reinit=True)
    ai_response = _call_agent(query)
```

---

## インフラ構成の詳細

### Terraformでコード管理

インフラはすべてTerraformで定義。`terraform apply`一発で環境構築できます。

```
terraform/
├── main.tf           # メインエントリポイント
├── lambda.tf         # Lambda関数
├── api_gateway.tf    # API Gateway
├── ecr.tf            # コンテナレジストリ
├── iam.tf            # IAMロール・ポリシー
├── ssm.tf            # Parameter Store
└── environments/
    ├── dev.tfvars    # 開発環境
    └── prod.tfvars   # 本番環境
```

📸 **[スクショ: terraform applyの実行結果]**

### API Gatewayの設定

- スロットリング（100 req/sec）で悪用防止
- CloudWatch Logsでリクエスト/レスポンスを記録
- メトリクスでモニタリング

📸 **[スクショ: API Gatewayのダッシュボード]**

---

## 開発中にハマったこと

### 1. MCPサーバーをnpxで起動できない問題

通常、MCPサーバーは`npx`で起動します：

```python
# 普通はこう書きたい
MCPClient(lambda: stdio_client(
    StdioServerParameters(
        command="npx",
        args=["-y", "@modelcontextprotocol/server-google-maps"],
        env=env
    )
))
```

しかしLambdaコンテナ内では`npx`が使えず、以下のようなエラーが発生：

```
Error: Cannot find module 'npx'
```

**解決策**: `node_modules`を事前にインストールし、`node`で直接実行

```python
# nodeで直接index.jsを実行
MCPClient(lambda: stdio_client(
    StdioServerParameters(
        command="node",
        args=["/var/task/node_modules/@modelcontextprotocol/server-google-maps/dist/index.js"],
        env=env
    )
))
```

Dockerfileでは、マルチステージビルドでNode.jsとnode_modulesだけをコピー：

```dockerfile
FROM public.ecr.aws/lambda/nodejs:20 AS nodebuild
WORKDIR /var/task
COPY package.json package-lock.json* ./
RUN npm ci

FROM public.ecr.aws/lambda/python:3.12
WORKDIR /var/task

# nodeバイナリだけコピー（npm不要）
COPY --from=nodebuild /var/lang/bin/node /var/lang/bin/node

# MCPサーバの依存を同梱
COPY --from=nodebuild /var/task/node_modules /var/task/node_modules
```

### 2. Pythonの`secrets`モジュールと名前衝突

自作の`secrets.py`がPython標準ライブラリと衝突してエラーに。`ssm_secrets.py`にリネームして解決。

```
Runtime.ImportModuleError: Unable to import module 'app': 
cannot import name 'token_hex' from 'secrets'
```

### 3. Mac (Apple Silicon) でのDockerビルド

普通にビルドするとLambdaで動かない！以下のオプションが必須でした。

```bash
docker build --platform linux/amd64 --provenance=false --sbom=false -t line-shop-bot .
```

### 4. Bedrock権限の追加忘れ

LambdaからBedrockを呼び出す権限をIAMポリシーに追加し忘れて`AccessDeniedException`。

---

## 今後の展望

- 🔜 お気に入り店舗の保存機能
- 🔜 予約サイトへの直接リンク
- 🔜 過去の検索履歴からのレコメンド
- 🔜 多言語対応（英語、中国語）

---

## まとめ

LINEで「@お店」と送るだけでAIがお店を探してくれるBot、ぜひ使ってみてください！

技術的には、Bedrock + Google Maps API + Lambda + API Gatewayというサーバーレス構成で、Terraformでインフラをコード管理しています。

📸 **[スクショ: 最後にもう一度、Botの動作画面]**

---

## 参考リンク

- [Amazon Bedrock](https://aws.amazon.com/bedrock/)
- [Google Maps Platform](https://developers.google.com/maps)
- [LINE Messaging API](https://developers.line.biz/ja/docs/messaging-api/)
