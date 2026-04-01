#!/bin/bash
# VoiceVox音声通知ラッパー
# VoiceVoxが起動している場合はVoiceVoxで再生、未起動の場合はmacOS sayにフォールバック

set -euo pipefail

TEXT="${*:-通知}"

VOICEVOX_HOST="${VOICEVOX_HOST:-http://127.0.0.1:50021}"

# 一時ディレクトリのクリーンアップ
TMPDIR_NOTIFY=""
cleanup() {
  [[ -n "$TMPDIR_NOTIFY" && -d "$TMPDIR_NOTIFY" ]] && rm -rf "$TMPDIR_NOTIFY"
}
trap cleanup EXIT

# `/speakers` の取得に失敗したときだけ使う安全なフォールバック
FALLBACK_SPEAKERS=(1 3 0 8)
FALLBACK_SPEAKER_NAMES=(
  [1]="ずんだもん(ノーマル)"
  [3]="ずんだもん(あまあま)"
  [0]="四国めたん(ノーマル)"
  [8]="春日部つむぎ(ノーマル)"
)

fetch_available_speakers() {
  curl -s --connect-timeout 2 "${VOICEVOX_HOST}/speakers" 2>/dev/null \
    | python3 -c '
import json
import sys

try:
    speakers = json.load(sys.stdin)
except Exception:
    sys.exit(1)

for speaker in speakers:
    name = speaker.get("name", "")
    for style in speaker.get("styles", []):
        style_id = style.get("id")
        style_name = style.get("name", "")
        if style_id is None:
            continue
        print(style_id)
' || return 1
}

choose_speaker_id() {
  if [[ -n "${VOICEVOX_SPEAKER:-}" ]]; then
    echo "$VOICEVOX_SPEAKER"
    return 0
  fi

  local discovered=()
  local discovered_raw
  if discovered_raw="$(fetch_available_speakers)"; then
    local old_ifs="$IFS"
    IFS=$'\n'
    discovered=($discovered_raw)
    IFS="$old_ifs"
  fi

  if [[ ${#discovered[@]} -gt 0 ]]; then
    echo "${discovered[$((RANDOM % ${#discovered[@]}))]}"
    return 0
  fi

  echo "${FALLBACK_SPEAKERS[$((RANDOM % ${#FALLBACK_SPEAKERS[@]}))]}"
}

# キャラ口調変換
transform_text() {
  local speaker_id="$1"
  local text="$2"

  case "$speaker_id" in
    1)
      # ずんだもん(ノーマル): 〜なのだ語尾
      echo "$text" \
        | sed 's/ is complete at /が完了なのだ！/g' \
        | sed 's/$/なのだ！/'
      ;;
    3)
      # ずんだもん(あまあま): 〜なのだ語尾(甘め)
      echo "$text" \
        | sed 's/ is complete at /が完了なのだ〜！/g' \
        | sed 's/$/なのだ〜！/'
      ;;
    0)
      # 四国めたん: 丁寧語 〜ですわ
      echo "$text" \
        | sed 's/ is complete at /が完了しましたわ。/g' \
        | sed 's/$/ですわ。/'
      ;;
    8)
      # 春日部つむぎ: カジュアル 〜だよ
      echo "$text" \
        | sed 's/ is complete at /が完了だよー！/g' \
        | sed 's/$/だよー！/'
      ;;
    *)
      echo "$text"
      ;;
  esac
}

# VoiceVox起動チェック & 音声合成
voicevox_speak() {
  local text="$1"

  # 起動チェック
  if ! curl -s --connect-timeout 1 "${VOICEVOX_HOST}/version" > /dev/null 2>&1; then
    return 1
  fi

  # 話者選択
  local speaker_id
  speaker_id="$(choose_speaker_id)"

  # 口調変換
  local transformed
  transformed="$(transform_text "$speaker_id" "$text")"

  # 一時ディレクトリ作成
  TMPDIR_NOTIFY="$(mktemp -d)"

  # audio_queryでクエリ生成
  local query_file="${TMPDIR_NOTIFY}/query.json"
  local encoded_text
  encoded_text="$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$transformed")"
  if ! curl -s --connect-timeout 5 -X POST \
    "${VOICEVOX_HOST}/audio_query?text=${encoded_text}&speaker=${speaker_id}" \
    -H "Content-Type: application/json" \
    -o "$query_file" 2>/dev/null; then
    return 1
  fi

  # synthesisでWAV生成
  local wav_file="${TMPDIR_NOTIFY}/output.wav"
  if ! curl -s --connect-timeout 10 -X POST \
    "${VOICEVOX_HOST}/synthesis?speaker=${speaker_id}" \
    -H "Content-Type: application/json" \
    -d @"$query_file" \
    -o "$wav_file" 2>/dev/null; then
    return 1
  fi

  # WAVファイルサイズチェック
  if [[ ! -s "$wav_file" ]]; then
    return 1
  fi

  # afplayで再生
  afplay "$wav_file" 2>/dev/null
  return 0
}

# メイン処理
if ! voicevox_speak "$TEXT"; then
  say "$TEXT"
fi
