# personal-claude-skills

Claude Code で使うカスタムスキルを管理するリポジトリ。

## セットアップ

```bash
bash setup.sh
```

`skills/` 配下の各スキルディレクトリを `~/.claude/skills/` にシンボリックリンクとして配置します。リンク済みの場合はスキップされます。

## スキル一覧

| スキル名 | 概要 |
|---|---|
| [daily-work-summary](skills/daily-work-summary/SKILL.md) | Notion上のインラインデータベースに日次作業メモを自動生成。Git/Linearの実績収集、構造化、ヒアリングによる振り返り、課題の解決アプローチ提案まで一括実行。 |

## スキルの追加方法

1. `skills/<skill-name>/SKILL.md` を作成する
2. `bash setup.sh` を実行してシンボリックリンクを作成する

`SKILL.md` のフロントマターには以下を記載します:

```yaml
---
name: skill-name
description: >
  スキルの説明文。トリガーとなるキーワードも含める。
argument-hint: "[引数の説明]"
---
```
