# WezTerm: シェルプロンプト表示時にclaude_stateをリセット
_reset_claude_state() {
  [[ -n "$WEZTERM_PANE" ]] && printf '\033]1337;SetUserVar=%s=%s\007' claude_state "$(printf '%s' idle | base64)"
}
precmd_functions+=(_reset_claude_state)
