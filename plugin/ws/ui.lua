local wezterm = require 'wezterm' ---@type Wezterm
local act = wezterm.action

local os_date = os.date
local table_concat = table.concat
local table_insert = table.insert
local tostring = tostring
local type = type

local wezterm_format = wezterm.format
local wezterm_nerdfonts = wezterm.nerdfonts or {}

local Utils = require 'ws.utils'

local M = {}

local selector_alphabet = 'saoxced1234567890brfghilmnpqtuvwyz'
local selector_separator =
  '─────────────────────────────────────────────────────────'
local no_workspaces_body = 'No live workspaces found.'
local no_saved_workspaces_body =
  'No saved workspace states found. Open the selector, then press s or a.'
local disable_reverse_video = '\x1b[27m'

---@param window Window
---@param title string
---@param body string
function M.notify(window, title, body)
  window:toast_notification(title, body)
end

---@param window Window
function M.notify_no_workspaces(window)
  M.notify(window, 'No Workspaces', no_workspaces_body)
end

---@param window Window
function M.notify_no_saved_workspaces(window)
  M.notify(window, 'No Saved Workspace States', no_saved_workspaces_body)
end

---@param window Window
---@param pane Pane
---@param opts WsWezInputSelectorOpts
function M.show_input_selector(window, pane, opts)
  window:perform_action(
    act.InputSelector {
      action = wezterm.action_callback(opts.on_select),
      title = opts.title,
      choices = opts.choices,
      alphabet = selector_alphabet,
      description = opts.description,
      fuzzy_description = opts.fuzzy_description,
    },
    pane
  )
end

---@return string
function M.selector_separator()
  return selector_separator
end

---@param value string|nil
---@return string
local function resolve_style_component(value)
  if type(value) ~= 'string' or value == '' then
    return ''
  end

  return wezterm_nerdfonts[value] or value
end

---@param icon string
---@param text string
---@return string
local function join_icon_and_text(icon, text)
  local parts = {}

  if icon ~= '' then
    table_insert(parts, icon)
  end

  if text ~= '' then
    table_insert(parts, text)
  end

  return table_concat(parts, ' ')
end

---@return table[], { has_content: boolean }
local function start_label()
  return {
    { Text = disable_reverse_video },
  }, { has_content = false }
end

---@param elements table[]
---@param state { has_content: boolean }
---@param color string
---@param text string
---@param intensity 'Normal'|'Half'|'Bold'|nil
local function append_segment(elements, state, color, text, intensity)
  if text == '' then
    return
  end

  if state.has_content then
    table_insert(elements, { Text = ' ' })
  else
    state.has_content = true
  end

  table_insert(elements, { Foreground = { Color = color } })

  if intensity and intensity ~= 'Normal' then
    table_insert(elements, { Attribute = { Intensity = intensity } })
  end

  table_insert(elements, { Text = text })

  if intensity and intensity ~= 'Normal' then
    table_insert(elements, { Attribute = { Intensity = 'Normal' } })
  end
end

---@param text string
---@param config WsWezResolvedConfig
---@return string
function M.format_action_label(text, config)
  local label, state = start_label()

  append_segment(
    label,
    state,
    config.colors.action_prefix,
    join_icon_and_text(resolve_style_component(config.style.action), ''),
    nil
  )
  append_segment(label, state, config.colors.text, text, nil)

  return wezterm_format(label)
end

---@param name string
---@param is_current boolean
---@param pane_count integer
---@param config WsWezResolvedConfig
---@return string
function M.format_live_workspace_label(name, is_current, pane_count, config)
  local colors = config.colors
  local labels = config.labels
  local style = config.style
  local label, state = start_label()
  local pane_count_parts = {}

  table_insert(pane_count_parts, tostring(pane_count))

  local pane_count_icon = resolve_style_component(style.pane_count)

  if pane_count_icon ~= '' then
    table_insert(pane_count_parts, 1, pane_count_icon)
  end

  append_segment(
    label,
    state,
    colors.workspace_prefix,
    join_icon_and_text(resolve_style_component(style.workspace), labels.workspace),
    nil
  )
  append_segment(label, state, colors.text, name, nil)
  append_segment(
    label,
    state,
    colors.pane_count,
    '(' .. table_concat(pane_count_parts, ' ') .. ')',
    'Half'
  )

  if is_current then
    append_segment(
      label,
      state,
      colors.current_indicator,
      join_icon_and_text(resolve_style_component(style.current), labels.current),
      nil
    )
  end

  return wezterm_format(label)
end

---@param directory string
---@param config WsWezResolvedConfig
---@return string
function M.format_directory_label(directory, config)
  local colors = config.colors
  local labels = config.labels
  local label, state = start_label()

  append_segment(
    label,
    state,
    colors.zoxide_prefix,
    join_icon_and_text(resolve_style_component(config.style.zoxide), labels.zoxide),
    nil
  )
  append_segment(label, state, colors.text, Utils.basename(directory), nil)
  append_segment(label, state, colors.path, '(' .. directory .. ')', nil)

  return wezterm_format(label)
end

---@param saved_name string
---@param state WsWezSavedState|nil
---@param config WsWezResolvedConfig
---@return string
function M.format_saved_workspace_label(saved_name, state, config)
  local details = {}
  local label, segment_state = start_label()

  if
    type(state) == 'table'
    and type(state.timestamp) == 'number'
    and state.timestamp > 0
  then
    table_insert(details, os_date('%Y-%m-%d %H:%M', state.timestamp))
  end

  if type(state) == 'table' and type(state.cwd) == 'string' and state.cwd ~= '' then
    table_insert(details, state.cwd)
  end

  append_segment(label, segment_state, config.colors.text, saved_name, nil)

  if #details > 0 then
    append_segment(
      label,
      segment_state,
      config.colors.path,
      '(' .. table_concat(details, ' | ') .. ')',
      nil
    )
  end

  return wezterm_format(label)
end

return M
