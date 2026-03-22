# LINE Shop Bot AI Agent Ops (MVP)

## 目的
Slack からの指示を起点に、`develop` ブランチ向けの改善 PR を自動作成する。

- 対象 Slack チャンネル: `C0ANXG8KGF2`
- 対象リポジトリ: `clf13092/line-shop-bot`
- ベースブランチ: `develop`

## スコープ（MVP）
- 対応: 要件整理、実装、テスト、PR 作成、Slack 返信
- 非対応: 自動デプロイ（後続フェーズ）

## 受け付ける指示フォーマット
以下のいずれかで開始する。

- `improve: <改善内容>`
- `fix: <不具合内容 or issue番号>`
- `analyze: <調査内容>`

## 実行フロー
1. 指示を解析し、作業目的・完了条件を明文化
2. `develop` から作業ブランチ作成
3. 実装（最小差分）
4. テスト実行
   - `cd agentcore && pytest -q`
5. 変更概要を整理し、PR 作成
6. Slack に結果を返信（テンプレートに沿う）

## ブランチ命名規則
- `ai/improve-<yyyymmdd>-<short>`
- `ai/fix-<yyyymmdd>-<short>`
- `ai/analyze-<yyyymmdd>-<short>`

## PR ルール
- `main` への直 push 禁止
- 必ず `develop` 向け PR を作成
- PR 本文は `.github/pull_request_template.md` を使用

## Slack 返信テンプレート
```
✅ 実行結果
- 要約: <3行以内>
- 変更ファイル: <主要ファイル>
- テスト: <成功/失敗 + コマンド>
- リスク/未対応: <あれば>
- PR: <URL>
```

## 安全ガード
- 禁止コマンド: `terraform destroy`、DB 削除系、本番データ破壊操作
- 大きな仕様変更は「分割PR」を優先
- 不確実な変更は `analyze` を先に実行して提案のみ返す

## 将来フェーズ（任意）
- Slack 承認付き deploy コマンド追加
- `staging` 自動、`production` 手動承認
- デプロイ失敗時の自動ロールバック通知
