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

-- C: 右ステータスバーにテキスト表示
wezterm.on("update-right-status", function(window, pane)
  if not claude_notify.status_bar then
    return
  end

  local user_vars = pane:get_user_vars()
  if user_vars and user_vars.claude_state == "waiting" then
    window:set_right_status(wezterm.format({
      { Foreground = { Color = "#2d8a4e" } },
      { Background = { Color = "#1a1a2e" } },
      { Attribute = { Intensity = "Bold" } },
      { Text = " \u{25cf} WAITING FOR INPUT " },
    }))
  else
    window:set_right_status("")
  end
end)

-- B/D/E/G: user-var-changed でまとめて config overrides を適用
wezterm.on("user-var-changed", function(window, pane, name, value)
  if name ~= "claude_state" then
    return
  end

  local overrides = window:get_config_overrides() or {}
  local is_waiting = (value == "waiting")
  local is_working = (value == "working")

  -- B: カラースキーム切替（実行中のみ変更、入力待ち/idle時は通常）
  if claude_notify.color_scheme then
    if is_working then
      overrides.color_scheme = "GruvboxDark"
    else
      overrides.color_scheme = nil
    end
  end

  -- D: 背景透明度変更
  if claude_notify.opacity then
    if is_waiting then
      overrides.window_background_opacity = 0.6
    else
      overrides.window_background_opacity = nil
    end
  end

  -- E: タブバー背景色全体変更
  if claude_notify.tab_bar_bg then
    if not overrides.colors then
      overrides.colors = {}
    end
    if not overrides.colors.tab_bar then
      overrides.colors.tab_bar = {}
    end
    if is_waiting then
      overrides.colors.tab_bar.background = "#1a3a2a"
    else
      overrides.colors.tab_bar.background = nil
    end
  end

  -- G: カーソル色変更
  if claude_notify.cursor_color then
    if not overrides.colors then
      overrides.colors = {}
    end
    if is_waiting then
      overrides.colors.cursor_bg = "#2d8a4e"
      overrides.colors.cursor_fg = "#ffffff"
    else
      overrides.colors.cursor_bg = nil
      overrides.colors.cursor_fg = nil
    end
  end

  window:set_config_overrides(overrides)
end)
