#!/bin/bash
# スタンドアロンスクリプトに転送
exec "$(dirname "$0")/../../scripts/setup-wezterm-notify.sh" "$@"
