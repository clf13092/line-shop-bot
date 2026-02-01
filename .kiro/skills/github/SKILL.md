---
name: github
description: GitHub操作を支援するスキル。リポジトリ管理、Issue/PR操作、ブランチ管理、コミット履歴確認などGitHub CLIを使用した操作全般。以下の場合に使用: (1) Issue作成・更新・クローズ (2) PR作成・レビュー・マージ (3) リポジトリ情報取得 (4) ブランチ操作 (5) GitHub Actions確認 (6) リリース管理
---

# GitHub Operations Skill

GitHub CLIを使用したGitHub操作を支援する。

## 前提条件

- `gh` CLI がインストール済み
- `gh auth login` で認証済み

## テンプレート

Issue/PR作成時は [templates.md](references/templates.md) のフォーマットを使用する。

- バグ報告、機能要望、タスク、質問用のIssueテンプレート
- 機能追加、バグ修正、リファクタリング、ドキュメント、依存関係更新用のPRテンプレート
- 推奨ラベル一覧

## Issue/PR作成フロー

1. ユーザの要求からテンプレート種別を判断
2. templates.mdの該当テンプレートを確認
3. 必須項目が不足している場合、作成前にユーザに確認する
4. 情報が揃ったら `gh issue create` または `gh pr create` を実行

### 確認が必要な項目

**Issue作成時:**
- バグ報告: 再現手順、期待する動作、実際の動作
- 機能要望: 背景・課題、提案する解決策
- タスク: 完了条件

**PR作成時:**
- 関連Issue番号
- 変更内容の説明
- 動作確認の状況

## 基本操作

### Issue操作

```bash
# Issue一覧
gh issue list

# Issue作成
gh issue create --title "タイトル" --body "本文"

# Issue詳細
gh issue view <number>

# Issueクローズ
gh issue close <number>
```

### Pull Request操作

```bash
# PR一覧
gh pr list

# PR作成
gh pr create --title "タイトル" --body "本文"

# PR詳細・差分確認
gh pr view <number>
gh pr diff <number>

# PRマージ
gh pr merge <number> --merge
```

### リポジトリ操作

```bash
# リポジトリ情報
gh repo view

# クローン
gh repo clone <owner/repo>

# フォーク
gh repo fork <owner/repo>
```

### ブランチ・コミット

```bash
# ブランチからPR作成
gh pr create --base main --head feature-branch

# 最新コミット確認
gh api repos/{owner}/{repo}/commits --jq '.[0:5]'
```

### GitHub Actions

```bash
# ワークフロー一覧
gh workflow list

# 実行履歴
gh run list

# 実行詳細
gh run view <run-id>
```

### リリース

```bash
# リリース一覧
gh release list

# リリース作成
gh release create <tag> --title "タイトル" --notes "リリースノート"
```

## 認証確認

```bash
gh auth status
```
