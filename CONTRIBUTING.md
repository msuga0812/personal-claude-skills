# Contributing Guide

`personal-claude-skills` へのコントリビュートありがとうございます。

## 開発の流れ

1. リポジトリを Fork して、作業ブランチを作成します。
2. `bash setup.sh` を実行してローカルセットアップします。
3. 変更内容に対応するテスト・確認を行います。
4. Pull Request を作成します。

## 変更ルール

- スキルは `skills/<skill-name>/SKILL.md` に追加します。
- `SKILL.md` の frontmatter に `name` と `description` を必ず含めてください。
- 1つの Pull Request では、目的を1つに絞ってください。
- 既存の README やドキュメントと矛盾がある場合は、あわせて更新してください。

## Pull Request チェックリスト

- [ ] 目的と背景を説明した
- [ ] 変更箇所を説明した
- [ ] 影響範囲を確認した
- [ ] 必要なドキュメント更新を行った

## Issue の作成

- バグ報告・機能要望は Issue Template を使ってください。
- セキュリティに関する報告は公開 Issue ではなく `SECURITY.md` の手順に従ってください。

## 行動規範

参加者は `CODE_OF_CONDUCT.md` に従う必要があります。
