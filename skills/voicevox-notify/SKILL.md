---
name: voicevox-notify
description: >
  VoiceVox音声通知ラッパー。タスク完了時にVoiceVoxが起動していればキャラクター音声で通知し、未起動ならmacOS sayにフォールバックする。
  話者はVoiceVoxから動的取得してランダム選択され、キャラクターに合わせた口調に変換される。
  トリガー: 通知設定、voicevox notify、音声通知セットアップ
argument-hint: "[通知テキスト]"
---

# VoiceVox音声通知ラッパー

タスク完了時の音声通知をVoiceVoxで行うスクリプト。VoiceVoxが起動していない場合はmacOS `say`コマンドにフォールバックする。

## Prerequisites

- macOS (afplay, say コマンドが利用可能)
- Python 3 (urllib.parseによるURLエンコードに使用)
- VoiceVox (オプション、未起動時はsayにフォールバック)

## セットアップ

### 1. スクリプト配置

`setup.sh`を実行すると`~/.claude/scripts/notify.sh`にシンボリックリンクが作成される。

```bash
bash setup.sh
```

### 2. CLAUDE.md設定

`~/.claude/CLAUDE.md`の通知指示を変更:

```diff
-  - Use the following format and `say` to send notifications:
-    - `say "${TASK_DESCRIPTION} is complete at ${REPOSITORY_NAME}"`
+  - Use the following format and `~/.claude/scripts/notify.sh` to send notifications:
+    - `~/.claude/scripts/notify.sh "${TASK_DESCRIPTION} is complete at ${REPOSITORY_NAME}"`
```

### 3. settings.json設定

`~/.claude/settings.json`に以下を追加:

**permissions.allow**:
```json
"Bash(~/.claude/scripts/notify.sh:*)"
```

**hooks.Stop** (任意):
```json
{
  "type": "command",
  "command": "~/.claude/scripts/notify.sh stop"
}
```

## 使い方

```bash
# 直接実行
~/.claude/scripts/notify.sh "タスク完了 is complete at my-repo"

# Claude Codeから(CLAUDE.mdの通知指示経由)
~/.claude/scripts/notify.sh "${TASK_DESCRIPTION} is complete at ${REPOSITORY_NAME}"
```

## 話者選択

- 通常時: `GET /speakers` で取得できる全スタイルからランダム選択
- `VOICEVOX_SPEAKER` 指定時: その話者IDを固定使用
- `/speakers` 取得失敗時: 以下のフォールバック話者から選択

| Speaker ID | キャラクター | 口調 |
|---|---|---|
| 1 | ずんだもん(ノーマル) | 〜なのだ |
| 3 | ずんだもん(あまあま) | 〜なのだ〜 |
| 0 | 四国めたん(ノーマル) | 〜ですわ |
| 8 | 春日部つむぎ(ノーマル) | 〜だよー |

## 環境変数

| 変数 | デフォルト | 説明 |
|---|---|---|
| `VOICEVOX_HOST` | `http://127.0.0.1:50021` | VoiceVox APIのホスト |
| `VOICEVOX_SPEAKER` | (未設定=ランダム) | 固定話者ID。`curl "$VOICEVOX_HOST/speakers"` の `styles[].id` を指定 |

## 処理フロー

```
引数からテキスト取得
  |
  v
VoiceVox起動チェック (curl /version, timeout 1秒)
  |
  +-- 起動中 --> /speakers から話者一覧取得
  |              --> ランダムにspeaker_id選択
  |              --> 取得失敗時はフォールバック話者を使用
  |              --> テキストをキャラ口調に変換 (sed)
  |              --> /audio_query でクエリ生成
  |              --> /synthesis でWAV生成
  |              --> afplay で再生
  |              --> 失敗時 --> say にフォールバック
  |
  +-- 未起動 --> say コマンドで再生
```
