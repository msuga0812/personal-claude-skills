#!/bin/sh
# Claude Code hook -> WezTerm user-var通知スクリプト
# Usage: notify-wezterm.sh <state>  (state: "waiting" or "working")

state="${1:-working}"
encoded=$(printf '%s' "$state" | base64)

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

tty_dev=$(find_tty)
if [ -n "$tty_dev" ] && [ -w "$tty_dev" ]; then
  if [ "$state" = "working" ]; then
    # UserPromptSubmit: 即座に送信
    printf '\033]1337;SetUserVar=%s=%s\007' claude_state "$encoded" > "$tty_dev"
  else
    # Stop hook: Claude CodeのTUI復元完了を待ってからバックグラウンドで送信
    # （レースコンディション回避）
    (sleep 1 && printf '\033]1337;SetUserVar=%s=%s\007' claude_state "$encoded" > "$tty_dev") &
  fi
fi
