#!/bin/bash
# wezterm-claude-notify: 設定ファイルへの直接書き込みセットアップ
# マーカーコメントで囲んだブロックを各設定ファイルに注入（冪等）
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$HOME/.claude/scripts"
WEZTERM_LUA="$HOME/.config/wezterm/wezterm.lua"
ZSHRC="$HOME/.zshrc"
SETTINGS_JSON="$HOME/.claude/settings.json"

# マーカーで囲まれたブロックを挿入/置換する関数
# $1: ファイルパス  $2: 開始マーカー  $3: 終了マーカー  $4: 注入内容  $5: "before:PATTERN" (optional)
inject_block() {
  local file="$1" begin_marker="$2" end_marker="$3" content="$4" insert_mode="${5:-append}"

  if [ ! -f "$file" ]; then
    echo "error: $file not found"
    return 1
  fi

  # 既存ブロックがあれば削除（pythonでマーカー行を含む範囲を削除）
  if grep -qF -- "$begin_marker" "$file" 2>/dev/null; then
    local tmpfile
    tmpfile=$(mktemp)
    python3 -c "
import sys
skip = False
bm, em = sys.argv[1], sys.argv[2]
for line in open(sys.argv[3]):
    stripped = line.rstrip('\n')
    if bm in stripped:
        skip = True
        continue
    if em in stripped:
        skip = False
        continue
    if not skip:
        sys.stdout.write(line)
" "$begin_marker" "$end_marker" "$file" > "$tmpfile"
    mv "$tmpfile" "$file"
    echo "update: removed old block from $file"
  fi

  # ブロックを一時ファイルに書き出し
  local block_file
  block_file=$(mktemp)
  printf '%s\n%s\n%s\n' "$begin_marker" "$content" "$end_marker" > "$block_file"

  if [[ "$insert_mode" == before:* ]]; then
    # 指定パターンの直前に挿入
    local pattern="${insert_mode#before:}"
    local tmpfile
    tmpfile=$(mktemp)
    while IFS= read -r line; do
      if [[ "$line" == $pattern* ]]; then
        cat "$block_file"
      fi
      printf '%s\n' "$line"
    done < "$file" > "$tmpfile"
    mv "$tmpfile" "$file"
  else
    # 末尾に追加
    echo "" >> "$file"
    cat "$block_file" >> "$file"
  fi

  rm -f "$block_file"
  echo "inject: block added to $file"
}

# --- 1. notify-wezterm.sh をコピー ---
mkdir -p "$SCRIPTS_DIR"
src="$SKILL_DIR/notify-wezterm.sh"
dst="$SCRIPTS_DIR/notify-wezterm.sh"

if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
  echo "skip: scripts/notify-wezterm.sh (identical)"
else
  cp "$src" "$dst"
  chmod +x "$dst"
  echo "copy: notify-wezterm.sh -> $dst"
fi

# --- 2. wezterm.lua に Lua スニペットを注入 ---
if [ -f "$WEZTERM_LUA" ]; then
  lua_snippet=$(<"$SKILL_DIR/wezterm-snippet.lua")
  inject_block "$WEZTERM_LUA" \
    "-- BEGIN wezterm-claude-notify" \
    "-- END wezterm-claude-notify" \
    "$lua_snippet" \
    "before:return config"
else
  echo "warn: $WEZTERM_LUA not found, skipping wezterm.lua injection"
fi

# --- 3. .zshrc に precmd フックを注入 ---
if [ -f "$ZSHRC" ]; then
  zshrc_snippet=$(<"$SKILL_DIR/zshrc-snippet.sh")
  inject_block "$ZSHRC" \
    "# BEGIN wezterm-claude-notify" \
    "# END wezterm-claude-notify" \
    "$zshrc_snippet"
else
  echo "warn: $ZSHRC not found, skipping .zshrc injection"
fi

# --- 4. settings.json に hooks を追加 ---
if [ -f "$SETTINGS_JSON" ] && command -v jq &>/dev/null; then
  stop_cmd="~/.claude/scripts/notify-wezterm.sh waiting"
  submit_cmd="~/.claude/scripts/notify-wezterm.sh working"
  stop_entry='{"matcher":"","hooks":[{"type":"command","command":"'"$stop_cmd"'"}]}'
  submit_entry='{"matcher":"","hooks":[{"type":"command","command":"'"$submit_cmd"'"}]}'

  needs_update=false

  # Stop hook の存在チェック
  if ! jq -e ".hooks.Stop[]? | select(.hooks[]?.command == \"$stop_cmd\")" "$SETTINGS_JSON" &>/dev/null; then
    needs_update=true
  fi

  # UserPromptSubmit hook の存在チェック
  if ! jq -e ".hooks.UserPromptSubmit[]? | select(.hooks[]?.command == \"$submit_cmd\")" "$SETTINGS_JSON" &>/dev/null; then
    needs_update=true
  fi

  if [ "$needs_update" = true ]; then
    tmpfile=$(mktemp)
    jq --argjson stop_entry "$stop_entry" --argjson submit_entry "$submit_entry" '
      # hooks オブジェクトがなければ作成
      .hooks //= {} |
      # Stop 配列がなければ作成、既にコマンドがなければ追加
      .hooks.Stop //= [] |
      (if (.hooks.Stop | map(select(.hooks[]?.command == "~/.claude/scripts/notify-wezterm.sh waiting")) | length) == 0
       then .hooks.Stop += [$stop_entry]
       else . end) |
      # UserPromptSubmit 配列がなければ作成、既にコマンドがなければ追加
      .hooks.UserPromptSubmit //= [] |
      (if (.hooks.UserPromptSubmit | map(select(.hooks[]?.command == "~/.claude/scripts/notify-wezterm.sh working")) | length) == 0
       then .hooks.UserPromptSubmit += [$submit_entry]
       else . end)
    ' "$SETTINGS_JSON" > "$tmpfile"
    mv "$tmpfile" "$SETTINGS_JSON"
    echo "inject: hooks added to $SETTINGS_JSON"
  else
    echo "skip: hooks already present in $SETTINGS_JSON"
  fi
else
  if [ ! -f "$SETTINGS_JSON" ]; then
    echo "warn: $SETTINGS_JSON not found, skipping hooks injection"
  elif ! command -v jq &>/dev/null; then
    echo "warn: jq not found, skipping settings.json injection"
  fi
fi

echo "wezterm-claude-notify setup done."
