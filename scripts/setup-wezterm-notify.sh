#!/bin/bash
# wezterm-claude-notify: スタンドアロンセットアップスクリプト
# 全設定ファイルをheredocで埋め込み、単体でインストール/アンインストール可能
set -euo pipefail

# =============================================================================
# 定数定義
# =============================================================================
SCRIPTS_DIR="$HOME/.claude/scripts"
NOTIFY_SCRIPT="$SCRIPTS_DIR/notify-wezterm.sh"
ZSHRC="$HOME/.zshrc"
SETTINGS_JSON="$HOME/.claude/settings.json"

BEGIN_MARKER_LUA="-- BEGIN wezterm-claude-notify"
END_MARKER_LUA="-- END wezterm-claude-notify"
BEGIN_MARKER_SH="# BEGIN wezterm-claude-notify"
END_MARKER_SH="# END wezterm-claude-notify"

# =============================================================================
# heredoc関数: 埋め込みファイル内容
# =============================================================================

get_notify_script() {
  cat << 'HEREDOC_NOTIFY'
#!/bin/sh
# Claude Code hook -> WezTerm user-var通知スクリプト
# Usage: notify-wezterm.sh <state>  (state: "working", "asking", "idle")

state="${1:-working}"

# 親プロセスチェーンからTTYを特定
find_tty() {
  pid=$$
  while [ "$pid" != "1" ] && [ -n "$pid" ]; do
    t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$t" ] && [ "$t" != "??" ] && [ "$t" != "-" ]; then
      echo "/dev/$t"
      return 0
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
  return 1
}

send_state() {
  local s="$1"
  local enc
  enc=$(printf '%s' "$s" | base64)
  printf '\033]1337;SetUserVar=%s=%s\007' claude_state "$enc" > "$tty_dev"
}

tty_dev=$(find_tty)
if [ -n "$tty_dev" ] && [ -w "$tty_dev" ]; then
  case "$state" in
    working)
      # PostToolUse/UserPromptSubmit: 即座に送信
      send_state working
      ;;
    asking)
      # Notification(permission_prompt)/PreToolUse(AskUserQuestion): 即座に送信
      send_state asking
      ;;
    idle)
      # Stop/Notification(idle_prompt): TUI復元を待ってからバックグラウンドで送信
      (sleep 1 && send_state idle) &
      ;;
  esac
fi
HEREDOC_NOTIFY
}

get_lua_snippet() {
  cat << 'HEREDOC_LUA'
-- Claude Code入力待ち通知 - 有効/無効切り替え
local claude_notify = {
  tab_color = false,          -- A: アクティブタブ色変更
  color_scheme = true,        -- B: カラースキーム全体切替
  status_bar = true,          -- C: 右ステータスバーにテキスト表示
  opacity = false,            -- D: 背景透明度変更（デフォルトoff）
  tab_bar_bg = false,         -- E: タブバー背景色全体変更
  visual_bell = true,         -- F: 画面フラッシュ（Stop時のみ1回）
  cursor_color = false,       -- G: カーソル色変更
}

-- カラースキーム設定（カスタマイズ用定数）
local BASE_SCHEME = "iceberg-dark"
local WORKING_SCHEME = "AdventureTime"
local ASKING_BG = "#3d1215"

-- Visual Bell設定 (手段F)
if claude_notify.visual_bell then
  config.visual_bell = {
    fade_in_function = 'EaseIn',
    fade_in_duration_ms = 75,
    fade_out_function = 'EaseOut',
    fade_out_duration_ms = 150,
    target = 'CursorColor',
  }
  config.audible_bell = 'Disabled'
end

-- ステータスバー有効化 (手段C)
if claude_notify.status_bar then
  config.enable_tab_bar = true
end

-- A: アクティブタブ色変更
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local background = "#5c6d74"
  local foreground = "#FFFFFF"
  if tab.is_active then
    background = "#ae8b2d"
    foreground = "#FFFFFF"

    -- Claude入力待ち時はタブ色を緑に変更
    if claude_notify.tab_color then
      local user_vars = tab.active_pane.user_vars
      if user_vars and user_vars.claude_state == "waiting" then
        background = "#2d8a4e"
      end
    end
  end
  local title = "   " .. wezterm.truncate_right(tab.active_pane.title, max_width - 1) .. "   "
  return {
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Text = title },
  }
end)

-- 状態キャッシュ（ペインIDごとに管理、複数ウィンドウ対応）
local last_claude_state = {}

-- B/C/D/E/G: update-right-status で全オーバーライドを一元管理
-- user-var-changed ではなく update-right-status を使うことでカラースキーム変更が確実に反映される
wezterm.on("update-right-status", function(window, pane)
  local pane_id = tostring(pane:pane_id())
  local user_vars = pane:get_user_vars()
  local claude_state = user_vars and user_vars.claude_state or ""

  -- Claude Codeが実行されていないペインはスキップ
  if claude_state == "" then
    return
  end

  -- 状態が変化していなければ何もしない
  if claude_state == last_claude_state[pane_id] then
    return
  end
  last_claude_state[pane_id] = claude_state

  local is_working = (claude_state == "working")
  local is_waiting = (claude_state == "waiting")

  local overrides = {}

  -- B: カラースキーム切替（working/asking/idle の3状態）
  if claude_notify.color_scheme then
    if is_working then
      overrides.color_scheme = WORKING_SCHEME
    elseif claude_state == "asking" then
      overrides.color_scheme = BASE_SCHEME
      overrides.colors = { background = ASKING_BG }
    else
      overrides.color_scheme = BASE_SCHEME
    end
  end

  -- D: 背景透明度変更
  if claude_notify.opacity and is_waiting then
    overrides.window_background_opacity = 0.6
  end

  -- E: タブバー背景色全体変更
  if claude_notify.tab_bar_bg and is_waiting then
    if not overrides.colors then overrides.colors = {} end
    overrides.colors.tab_bar = { background = "#1a3a2a" }
  end

  -- G: カーソル色変更
  if claude_notify.cursor_color and is_waiting then
    if not overrides.colors then overrides.colors = {} end
    overrides.colors.cursor_bg = "#2d8a4e"
    overrides.colors.cursor_fg = "#ffffff"
  end

  window:set_config_overrides(overrides)

  -- C: 右ステータスバーにテキスト表示
  if claude_notify.status_bar then
    if claude_state == "waiting" then
      window:set_right_status(wezterm.format({
        { Foreground = { Color = "#2d8a4e" } },
        { Background = { Color = "#1a1a2e" } },
        { Attribute = { Intensity = "Bold" } },
        { Text = " \u{25cf} WAITING FOR INPUT " },
      }))
    else
      window:set_right_status("")
    end
  end
end)
HEREDOC_LUA
}

get_zshrc_snippet() {
  cat << 'HEREDOC_ZSHRC'
# WezTerm: シェルプロンプト表示時にclaude_stateをリセット
_reset_claude_state() {
  [[ -n "$WEZTERM_PANE" ]] && printf '\033]1337;SetUserVar=%s=%s\007' claude_state "$(printf '%s' idle | base64)"
}
precmd_functions+=(_reset_claude_state)
HEREDOC_ZSHRC
}

# =============================================================================
# ユーティリティ関数
# =============================================================================

# マーカーで囲まれたブロックを注入（冪等）
# $1: ファイルパス  $2: 開始マーカー  $3: 終了マーカー  $4: 注入内容  $5: "before:PATTERN" (optional)
inject_block() {
  local file="$1" begin_marker="$2" end_marker="$3" content="$4" insert_mode="${5:-append}"

  if [ ! -f "$file" ]; then
    echo "error: $file not found"
    return 1
  fi

  # 既存ブロックがあれば削除
  remove_block "$file" "$begin_marker" "$end_marker"

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

# マーカーブロックを削除
# $1: ファイルパス  $2: 開始マーカー  $3: 終了マーカー
remove_block() {
  local file="$1" begin_marker="$2" end_marker="$3"

  if [ ! -f "$file" ]; then
    return 0
  fi

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
    echo "remove: block removed from $file"
  fi
}

# WezTerm設定ファイルを検出
# ~/.wezterm.luaが存在する場合はそちらが優先されるため、適切なファイルを返す
detect_wezterm_config() {
  local home_lua="$HOME/.wezterm.lua"
  local config_lua="$HOME/.config/wezterm/wezterm.lua"

  if [ -L "$home_lua" ]; then
    # シンボリックリンク -> リンク先を解決して注入
    local resolved
    resolved=$(readlink -f "$home_lua")
    echo "$resolved"
  elif [ -f "$home_lua" ]; then
    # 通常ファイル -> WezTermがこちらを優先するためこちらに注入
    echo "$home_lua"
  elif [ -f "$config_lua" ]; then
    echo "$config_lua"
  else
    # どちらもなし -> ~/.config/wezterm/wezterm.luaを新規作成
    mkdir -p "$HOME/.config/wezterm"
    cat > "$config_lua" << 'EOF'
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

return config
EOF
    echo "create: $config_lua (new file)" >&2
    echo "$config_lua"
  fi
}

# =============================================================================
# インストール関数
# =============================================================================

# notify-wezterm.shを~/.claude/scripts/に配置
install_notify_script() {
  mkdir -p "$SCRIPTS_DIR"

  local new_content
  new_content=$(get_notify_script)

  if [ -f "$NOTIFY_SCRIPT" ] && [ "$(cat "$NOTIFY_SCRIPT")" = "$new_content" ]; then
    echo "skip: $NOTIFY_SCRIPT (identical)"
  else
    printf '%s\n' "$new_content" > "$NOTIFY_SCRIPT"
    chmod +x "$NOTIFY_SCRIPT"
    echo "install: $NOTIFY_SCRIPT"
  fi
}

# WezTerm Luaスニペットを注入
inject_wezterm_lua() {
  local wezterm_lua
  wezterm_lua=$(detect_wezterm_config)

  local lua_snippet
  lua_snippet=$(get_lua_snippet)

  inject_block "$wezterm_lua" \
    "$BEGIN_MARKER_LUA" \
    "$END_MARKER_LUA" \
    "$lua_snippet" \
    "before:return config"
}

# .zshrcにprecmdフックを注入
inject_zshrc() {
  if [ ! -f "$ZSHRC" ]; then
    echo "warn: $ZSHRC not found, creating it"
    touch "$ZSHRC"
  fi

  local zshrc_snippet
  zshrc_snippet=$(get_zshrc_snippet)

  inject_block "$ZSHRC" \
    "$BEGIN_MARKER_SH" \
    "$END_MARKER_SH" \
    "$zshrc_snippet"
}

# settings.jsonにhooksを注入（SKILL.md設計通り全6種）
inject_hooks() {
  if ! command -v jq &>/dev/null; then
    echo "warn: jq not found, skipping settings.json injection"
    return 0
  fi

  # settings.jsonがなければ初期化
  if [ ! -f "$SETTINGS_JSON" ]; then
    mkdir -p "$(dirname "$SETTINGS_JSON")"
    echo '{}' > "$SETTINGS_JSON"
    echo "create: $SETTINGS_JSON"
  fi

  local notify_cmd="~/.claude/scripts/notify-wezterm.sh"
  local tmpfile
  tmpfile=$(mktemp)

  jq --arg cmd "$notify_cmd" '
    .hooks //= {} |

    # UserPromptSubmit -> working
    .hooks.UserPromptSubmit //= [] |
    (if (.hooks.UserPromptSubmit | map(select(.hooks[]?.command | test($cmd))) | length) == 0
     then .hooks.UserPromptSubmit += [{"matcher":"","hooks":[{"type":"command","command":($cmd + " working")}]}]
     else . end) |

    # Notification -> asking (matcherを空文字列で全Notificationに対応)
    .hooks.Notification //= [] |
    (if (.hooks.Notification | map(select(.hooks[]?.command | test($cmd))) | length) == 0
     then .hooks.Notification += [{"matcher":"","hooks":[{"type":"command","command":($cmd + " asking")}]}]
     else . end) |

    # Stop -> idle
    .hooks.Stop //= [] |
    (if (.hooks.Stop | map(select(.hooks[]?.command | test($cmd))) | length) == 0
     then .hooks.Stop += [{"matcher":"","hooks":[{"type":"command","command":($cmd + " idle")}]}]
     else . end)
  ' "$SETTINGS_JSON" > "$tmpfile"

  mv "$tmpfile" "$SETTINGS_JSON"
  echo "inject: hooks added to $SETTINGS_JSON"
}

# =============================================================================
# アンインストール関数
# =============================================================================

uninstall() {
  echo "=== wezterm-claude-notify uninstall ==="

  # 1. notify-wezterm.shを削除
  if [ -f "$NOTIFY_SCRIPT" ]; then
    rm "$NOTIFY_SCRIPT"
    echo "remove: $NOTIFY_SCRIPT"
  else
    echo "skip: $NOTIFY_SCRIPT (not found)"
  fi

  # 2. wezterm.luaからマーカーブロック削除
  local wezterm_lua
  # アンインストール時は既存ファイルのみ対象（新規作成しない）
  local home_lua="$HOME/.wezterm.lua"
  local config_lua="$HOME/.config/wezterm/wezterm.lua"

  if [ -L "$home_lua" ]; then
    wezterm_lua=$(readlink -f "$home_lua")
  elif [ -f "$home_lua" ]; then
    wezterm_lua="$home_lua"
  elif [ -f "$config_lua" ]; then
    wezterm_lua="$config_lua"
  else
    wezterm_lua=""
  fi

  if [ -n "$wezterm_lua" ]; then
    remove_block "$wezterm_lua" "$BEGIN_MARKER_LUA" "$END_MARKER_LUA"
  else
    echo "skip: wezterm.lua (not found)"
  fi

  # 3. .zshrcからマーカーブロック削除
  remove_block "$ZSHRC" "$BEGIN_MARKER_SH" "$END_MARKER_SH"

  # 4. settings.jsonからnotify-wezterm.shを含むhookエントリを除去
  if [ -f "$SETTINGS_JSON" ] && command -v jq &>/dev/null; then
    local notify_cmd="~/.claude/scripts/notify-wezterm.sh"
    local tmpfile
    tmpfile=$(mktemp)

    jq --arg cmd "$notify_cmd" '
      if .hooks then
        .hooks |= with_entries(
          .value |= map(select(.hooks | all(.command | test($cmd) | not)))
          | if .value == [] then empty else . end
        )
        | if .hooks == {} then del(.hooks) else . end
      else . end
    ' "$SETTINGS_JSON" > "$tmpfile"

    mv "$tmpfile" "$SETTINGS_JSON"
    echo "remove: hooks from $SETTINGS_JSON"
  else
    echo "skip: settings.json hooks removal (file or jq not found)"
  fi

  echo "=== uninstall complete ==="
}

# =============================================================================
# メイン
# =============================================================================

main() {
  case "${1:-}" in
    --uninstall|-u)
      uninstall
      ;;
    --help|-h)
      echo "Usage: $(basename "$0") [OPTIONS]"
      echo ""
      echo "wezterm-claude-notify セットアップスクリプト"
      echo ""
      echo "Options:"
      echo "  --uninstall, -u  設定を全て除去"
      echo "  --help, -h       このヘルプを表示"
      ;;
    "")
      echo "=== wezterm-claude-notify setup ==="
      install_notify_script
      inject_wezterm_lua
      inject_zshrc
      inject_hooks
      echo "=== setup complete ==="
      ;;
    *)
      echo "error: unknown option: $1" >&2
      echo "Usage: $(basename "$0") [--uninstall | --help]" >&2
      exit 1
      ;;
  esac
}

main "$@"
