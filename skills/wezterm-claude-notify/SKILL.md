---
name: wezterm-claude-notify
description: >
  WezTerm + Claude Code 視覚通知。Claude Code実行中にカラースキームを切り替え、
  入力待ち時にステータスバーを表示する。hookスクリプトがiTerm2互換のuser-varエスケープシーケンスを
  WezTermのpaneに送信し、Lua側でconfig overridesを適用する。
  トリガー: wezterm通知設定、claude visual notify、ターミナル視覚通知
argument-hint: ""
---

# WezTerm + Claude Code 視覚通知

Claude Codeの状態（実行中/入力待ち/アイドル）をWezTermの視覚的変化で通知する仕組み。

## 仕組み

```
Claude Code hooks
  |
  |-- UserPromptSubmit        -> notify-wezterm.sh working
  |-- Notification(permission_prompt) -> notify-wezterm.sh asking
  |-- Notification(idle_prompt)       -> notify-wezterm.sh idle
  |-- PreToolUse(AskUserQuestion)     -> notify-wezterm.sh asking
  |-- PostToolUse(全ツール)           -> notify-wezterm.sh working
  |-- Stop                            -> notify-wezterm.sh idle
  v
notify-wezterm.sh <state>
  |-- 親プロセスチェーンからTTYデバイスを特定
  |-- iTerm2互換エスケープシーケンスでuser-var設定
  v
WezTerm Lua (update-right-status イベント)
  |-- ペインIDごとの状態キャッシュで変化時のみ処理（複数ウィンドウ対応）
  |-- claude_state の値に応じてconfig overridesを適用
  v
視覚変化（カラースキーム切替、ステータスバー表示等）
```

### 状態遷移

| 状態 | トリガー | 視覚効果 |
|------|---------|---------|
| `working` | UserPromptSubmit / PostToolUse | カラースキーム変更（AdventureTime） |
| `asking` | Notification(permission_prompt) / PreToolUse(AskUserQuestion) | 背景色変更（赤系 #3d1215） |
| `idle` | Stop / Notification(idle_prompt) | 通常表示に復帰（iceberg-dark） |

## Prerequisites

- WezTerm
- macOS（`ps`コマンドによるTTY検出）
- zsh

## セットアップ

ルートの`setup.sh`を実行すると、以下の4箇所に自動で設定を注入する:

```bash
bash setup.sh
```

| 対象ファイル | 処理 |
|-------------|------|
| `~/.claude/scripts/notify-wezterm.sh` | スクリプトをコピー |
| `~/.config/wezterm/wezterm.lua` | マーカーブロックを`return config`直前に注入 |
| `~/.zshrc` | マーカーブロックを末尾に注入 |
| `~/.claude/settings.json` | `jq`でhooksエントリを追加 |

マーカーコメント（`BEGIN/END wezterm-claude-notify`）で囲まれたブロックとして注入するため、
再実行時は既存ブロックを置換し冪等に動作する。

### 手動セットアップ

スキル固有のsetup.shを直接実行することも可能:

```bash
bash skills/wezterm-claude-notify/setup.sh
```

## カスタマイズ

### 通知手段の切り替え

`claude_notify`テーブルの各フラグで個別に有効/無効を制御:

| フラグ | 効果 | デフォルト |
|--------|------|-----------|
| `tab_color` | アクティブタブの色を変更 | off |
| `color_scheme` | カラースキーム全体を切替 | on |
| `status_bar` | 右ステータスバーにテキスト表示 | on |
| `opacity` | 背景透明度を変更 | off |
| `tab_bar_bg` | タブバー背景色を変更 | off |
| `visual_bell` | 画面フラッシュ（Stop時） | on |
| `cursor_color` | カーソル色を変更 | off |

### カラースキーム変更

`wezterm-snippet.lua`内の定数を変更:

```lua
local BASE_SCHEME = "iceberg-dark"     -- idle時のカラースキーム
local WORKING_SCHEME = "AdventureTime" -- working時のカラースキーム
local ASKING_BG = "#3d1215"            -- asking時の背景色
```

## hooks設定例

`~/.claude/settings.json` に以下のhooksを設定する:

```json
{
  "hooks": {
    "Notification": [
      { "matcher": "permission_prompt", "hooks": [{ "type": "command", "command": "~/.claude/scripts/notify-wezterm.sh asking" }] },
      { "matcher": "idle_prompt", "hooks": [{ "type": "command", "command": "~/.claude/scripts/notify-wezterm.sh idle" }] }
    ],
    "PreToolUse": [
      { "matcher": "AskUserQuestion", "hooks": [{ "type": "command", "command": "~/.claude/scripts/notify-wezterm.sh asking" }] }
    ],
    "PostToolUse": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/scripts/notify-wezterm.sh working" }] }
    ],
    "UserPromptSubmit": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/scripts/notify-wezterm.sh working" }] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/scripts/notify-wezterm.sh idle" }] }
    ]
  }
}
```

## 技術的な注意点

- hookコマンドのstdoutはWezTermのターミナルストリームに接続されていないため、親プロセスチェーンからTTYデバイスを特定して直接書き込む
- `/bin/sh`の`echo -n`はPOSIX非準拠なため、`printf '%s'`を使用してbase64エンコードする
- WezTermのuser-varはiTerm2互換のエスケープシーケンス`\033]1337;SetUserVar=name=base64value\007`で設定する
- `update-right-status`イベントで状態変化を検出（`user-var-changed`ではconfig overridesの反映が不安定なため）
- 状態キャッシュはペインIDごとに管理し、複数ウィンドウ環境での干渉を防止
- idle時は`set_config_overrides({})`ではなく明示的に`BASE_SCHEME`を設定（空テーブルだとリセットが効かないWezTermの挙動に対応）
- Notificationフックの`permission_prompt`は承認ダイアログ表示時のみ発火するため、自動承認ツールでのチラつきが発生しない
