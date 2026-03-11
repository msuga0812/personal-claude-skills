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

-- B/C: update-right-status でカラースキーム切替 + ステータスバー表示
-- user-var-changed ではなく update-right-status を使うことで確実に反映される
wezterm.on("update-right-status", function(window, pane)
  local user_vars = pane:get_user_vars()
  local claude_state = user_vars and user_vars.claude_state or ""
  local is_working = (claude_state == "working")

  -- B: カラースキーム切替（working/asking/idle の3状態）
  if claude_notify.color_scheme then
    local overrides = window:get_config_overrides() or {}
    local current_scheme = overrides.color_scheme
    local current_bg = overrides.colors and overrides.colors.background
    if is_working then
      -- working: AdventureTime
      if current_scheme ~= "AdventureTime" or current_bg ~= nil then
        overrides.color_scheme = "AdventureTime"
        overrides.colors = nil
        window:set_config_overrides(overrides)
      end
    elseif claude_state == "asking" then
      -- asking: ベーススキーム + 暗い赤背景のカスタムオーバーライド
      local asking_bg = "#3d1215"
      if current_scheme ~= nil or current_bg ~= asking_bg then
        overrides.color_scheme = nil
        overrides.colors = { background = asking_bg }
        window:set_config_overrides(overrides)
      end
    else
      -- idle: ベースconfig に戻す
      if current_scheme ~= nil or current_bg ~= nil then
        overrides.color_scheme = nil
        overrides.colors = nil
        window:set_config_overrides(overrides)
      end
    end
  end

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

-- D/E/G: user-var-changed で即時適用が必要なオーバーライド
wezterm.on("user-var-changed", function(window, pane, name, value)
  if name ~= "claude_state" then
    return
  end

  local is_working = (value == "working")
  local is_waiting = (value == "waiting")
  local overrides = window:get_config_overrides() or {}

  -- D: 背景透明度変更
  if claude_notify.opacity then
    overrides.window_background_opacity = is_waiting and 0.6 or nil
  end

  -- E: タブバー背景色全体変更
  if claude_notify.tab_bar_bg then
    if not overrides.colors then overrides.colors = {} end
    if not overrides.colors.tab_bar then overrides.colors.tab_bar = {} end
    overrides.colors.tab_bar.background = is_waiting and "#1a3a2a" or nil
  end

  -- G: カーソル色変更
  if claude_notify.cursor_color then
    if not overrides.colors then overrides.colors = {} end
    overrides.colors.cursor_bg = is_waiting and "#2d8a4e" or nil
    overrides.colors.cursor_fg = is_waiting and "#ffffff" or nil
  end

  window:set_config_overrides(overrides)
end)
