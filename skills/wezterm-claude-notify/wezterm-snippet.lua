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
