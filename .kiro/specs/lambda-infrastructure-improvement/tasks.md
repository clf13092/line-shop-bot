# 実装計画: Lambdaインフラストラクチャ改善

## 概要

LINE Bot（お店検索アシスタント）のインフラをTerraformでコード化し、Parameter Store対応とAPI Gateway経由のセキュアな構成に移行する。

## タスク

- [x] 1. Terraformプロジェクト構造のセットアップ
  - [x] 1.1 Terraformディレクトリ構造を作成
    - `terraform/`ディレクトリを作成
    - `terraform/environments/`ディレクトリを作成
    - _要件: 1.1, 1.4_

  - [x] 1.2 プロバイダ設定ファイルを作成 (providers.tf)
    - AWSプロバイダの設定
    - リージョン設定
    - _要件: 1.1_

  - [x] 1.3 変数定義ファイルを作成 (variables.tf)
    - プロジェクト名、環境、リージョン変数
    - シークレット変数（sensitive指定）
    - Lambda設定変数
    - API Gateway設定変数
    - _要件: 1.4_

- [x] 2. ECRリポジトリの定義
  - [x] 2.1 ECRリポジトリリソースを作成 (ecr.tf)
    - リポジトリ作成
    - イメージスキャン設定
    - 暗号化設定
    - ライフサイクルポリシー
    - _要件: 1.2_

- [x] 3. IAMロール・ポリシーの定義
  - [x] 3.1 Lambda実行ロールを作成 (iam.tf)
    - 信頼ポリシー（Lambda用）
    - 基本実行ポリシー（CloudWatch Logs）
    - _要件: 1.3_

  - [x] 3.2 Parameter Store読み取りポリシーを追加
    - ssm:GetParameter権限
    - ssm:GetParameters権限
    - リソース制限（環境別パス）
    - _要件: 2.4_

- [x] 4. Parameter Storeパラメータの定義
  - [x] 4.1 SSMパラメータリソースを作成 (ssm.tf)
    - GOOGLE_MAPS_API_KEYパラメータ（SecureString）
    - CHANNEL_ACCESS_TOKENパラメータ（SecureString）
    - lifecycle ignore_changes設定
    - _要件: 2.3_

- [x] 5. Lambda関数の定義
  - [x] 5.1 Lambda関数リソースを作成 (lambda.tf)
    - コンテナイメージ設定
    - メモリ・タイムアウト設定
    - 環境変数設定（SSM_PREFIX等）
    - _要件: 1.1_

- [x] 6. API Gatewayの定義
  - [x] 6.1 REST APIリソースを作成 (api_gateway.tf)
    - REST API定義
    - /webhookリソース
    - POSTメソッド
    - Lambdaプロキシ統合
    - _要件: 3.1, 3.2_

  - [x] 6.2 API Gatewayデプロイメントとステージを作成
    - デプロイメントリソース
    - ステージリソース
    - スロットリング設定
    - _要件: 3.5_

  - [x] 6.3 CloudWatchログ設定を追加
    - ログ用IAMロール
    - アクセスログ設定
    - _要件: 3.4_

  - [x] 6.4 Lambda実行権限を追加
    - API GatewayからLambdaを呼び出す権限
    - _要件: 3.6_

- [x] 7. 出力値の定義
  - [x] 7.1 出力ファイルを作成 (outputs.tf)
    - API GatewayエンドポイントURL
    - ECRリポジトリURL
    - Lambda関数ARN
    - _要件: 1.5_

- [x] 8. 環境別変数ファイルの作成
  - [x] 8.1 開発環境変数ファイルを作成 (environments/dev.tfvars)
    - _要件: 1.4_

  - [x] 8.2 本番環境変数ファイルを作成 (environments/prod.tfvars)
    - _要件: 1.4_

- [x] 9. チェックポイント - Terraform設定の検証
  - `terraform init`と`terraform validate`を実行
  - `terraform plan`で設定を確認
  - 問題があればユーザーに確認

- [x] 10. アプリケーションコードの修正
  - [x] 10.1 secrets.pyモジュールを作成
    - SSMクライアント初期化
    - get_secret関数（キャッシュ付き）
    - フォールバック処理
    - _要件: 4.1, 4.2, 4.4_

  - [x] 10.2 app.pyをParameter Store対応に修正
    - secrets.pyからget_secretをインポート
    - GOOGLE_MAPS_API_KEYの取得をget_secretに変更
    - CHANNEL_ACCESS_TOKENの取得をget_secretに変更
    - _要件: 2.1, 2.2_

- [x] 11. チェックポイント - アプリケーションコードの検証
  - コードの構文チェック
  - 問題があればユーザーに確認

- [ ]* 12. ユニットテストの作成
  - [ ]* 12.1 テストディレクトリとファイルを作成
    - tests/ディレクトリ作成
    - tests/test_secrets.py作成
    - _要件: 2.1, 2.2, 2.5, 2.6, 4.2, 4.4_

- [x] 13. メインエントリポイントの作成
  - [x] 13.1 main.tfを作成
    - データソース定義（aws_caller_identity等）
    - 必要に応じてローカル変数
    - _要件: 1.1_

- [x] 14. 最終チェックポイント
  - すべてのファイルが正しく作成されていることを確認
  - 問題があればユーザーに確認

## 備考

- `*`マークのタスクはオプションで、スキップ可能
- 各タスクは特定の要件を参照しトレーサビリティを確保
- チェックポイントで段階的に検証を実施

