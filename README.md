# personal-claude-skills

Claude Code で使うカスタムスキルを管理するリポジトリ。

## セットアップ

```bash
bash setup.sh
```

`setup.sh` はインストール対象スキルを対話的に選択できます。

- 対話実行かつ `gum` 導入済み: 複数選択UIで選択
- 対話実行かつ `gum` 未導入: 番号入力で複数選択（`,`区切り）
- 非対話実行: `--all` または `-y` がない場合は何も導入せず終了

選択したスキルのみ `~/.claude/skills/` にシンボリックリンクされます。通常スキルでは同ディレクトリ内の`.sh`ファイルが `~/.claude/scripts/` にもシンボリックリンクされます。リンク済みの場合はスキップされます。

### オプション

```bash
bash setup.sh --all   # 全スキルを導入
bash setup.sh -y      # 非対話向けに全スキルを導入
bash setup.sh --help  # ヘルプ表示
```

## スキル一覧

| スキル名 | 概要 |
|---|---|
| [daily-work-summary](skills/daily-work-summary/SKILL.md) | Notion上のインラインデータベースに日次作業メモを自動生成。Git/Linearの実績収集、構造化、ヒアリングによる振り返り、課題の解決アプローチ提案まで一括実行。 |
| [voicevox-notify](skills/voicevox-notify/SKILL.md) | VoiceVox音声通知ラッパー。タスク完了時にVoiceVoxが起動していればキャラクター音声で通知し、未起動ならmacOS sayにフォールバック。 |
| [wezterm-claude-notify](skills/wezterm-claude-notify/SKILL.md) | WezTerm視覚通知。Claude Codeの状態（working/asking/idle）に応じてカラースキームや背景色を切り替え、承認待ちや入力待ちを視覚的に通知。 |

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

## 公開リポジトリ向けポリシー

- [Code of Conduct](.github/CODE_OF_CONDUCT.md)
- [Security Policy](.github/SECURITY.md)
