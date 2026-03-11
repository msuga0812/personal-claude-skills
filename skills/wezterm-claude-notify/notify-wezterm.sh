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
