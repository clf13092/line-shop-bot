# 要件ドキュメント

## はじめに

本ドキュメントは、LINE Bot（お店検索アシスタント）のLambdaアプリケーションにおけるインフラストラクチャ改善の要件を定義する。現在の手動構築・環境変数直接格納・Function URL公開という課題を解決し、Terraformによるコード管理・Parameter Store活用・API Gateway経由のセキュアな構成へ移行する。

## 用語集

- **Terraform**: HashiCorp社が開発したIaCツール。HCL（HashiCorp Configuration Language）でAWSインフラをコードとして定義する
- **Parameter_Store**: AWS Systems Manager Parameter Store。設定値やシークレットを安全に保存・管理するサービス
- **API_Gateway**: Amazon API Gateway。RESTful APIやWebSocket APIを作成・管理するサービス
- **Lambda**: AWS Lambda。サーバーレスでコードを実行するコンピューティングサービス
- **ECR**: Amazon Elastic Container Registry。Dockerコンテナイメージを保存・管理するサービス
- **Function_URL**: Lambda関数に直接HTTPエンドポイントを付与する機能（認証なしで公開可能）

## 要件

### 要件1: Terraformによるインフラのコード化

**ユーザーストーリー:** 開発者として、インフラをコードで管理したい。再現性のあるデプロイと変更管理ができるようにするため。

#### 受け入れ基準

1. Terraformはメモリ、タイムアウト、ランタイム設定を含むLambda関数の構成を定義すること
2. Terraformはコンテナイメージ保存用のECRリポジトリを定義すること
3. TerraformはLambda実行に必要なすべてのIAMロールとポリシーを定義すること
4. Terraformはコンテキストまたはパラメータを通じて複数のデプロイ環境（dev、staging、prod）をサポートすること
5. `terraform apply`が実行されたとき、Terraformは必要なすべてのAWSリソースを自動的にプロビジョニングすること

### 要件2: Parameter Storeによるシークレット管理

**ユーザーストーリー:** セキュリティ担当者として、機密情報をParameter Storeで管理したい。シークレットがコードや環境変数に直接露出しないようにするため。

#### 受け入れ基準

1. Lambdaは実行時にParameter_Storeから`GOOGLE_MAPS_API_KEY`を取得すること
2. Lambdaは実行時にParameter_Storeから`CHANNEL_ACCESS_TOKEN`を取得すること
3. Terraformは機密値に対してSecureString型のParameter_Storeパラメータを定義すること
4. TerraformはLambda実行ロールにParameter_Storeからの読み取り権限を付与すること
5. Parameter_Storeの値が更新されたとき、Lambdaは再デプロイなしで次回のコールドスタート時に新しい値を使用すること
6. Parameter_Storeの取得に失敗した場合、Lambdaは適切なエラーレスポンスを返すこと

### 要件3: API Gateway経由のセキュアなアクセス

**ユーザーストーリー:** セキュリティ担当者として、API Gatewayを経由してLambdaにアクセスさせたい。不正アクセスを防止しレート制限やログ記録ができるようにするため。

#### 受け入れ基準

1. TerraformはLINE webhook用のPOSTエンドポイントを持つAPI_Gateway REST APIを定義すること
2. API_Gatewayはプロキシ統合を使用してLambdaと連携すること
3. TerraformはLambdaのFunction_URL設定を含めないこと
4. API_Gatewayはリクエスト・レスポンス監視用のCloudWatchログを有効化すること
5. API_Gatewayは悪用防止のためのスロットリング制限を設定すること
6. リクエストがAPI_Gatewayに到着したとき、API_Gatewayは適切なイベント変換を行いLambdaに転送すること

### 要件4: アプリケーションコードの修正

**ユーザーストーリー:** 開発者として、アプリケーションコードをParameter Store対応に修正したい。新しいインフラ構成で動作するようにするため。

#### 受け入れ基準

1. Lambdaはコールドスタート時にboto3を使用してParameter_Storeクライアントを初期化すること
2. Lambdaはウォーム起動中、取得したシークレットをメモリにキャッシュすること
3. LambdaはAPI_Gatewayのイベント形式を正しく処理すること
4. 環境変数フォールバックが設定されている場合、LambdaはParameter_Storeが利用できないときに環境変数を使用すること（ローカルテスト用）

