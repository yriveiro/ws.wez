local wezterm = require 'wezterm' ---@type Wezterm
local act = wezterm.action

local os_date = os.date
local string_format = string.format
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

---@param elements table[]
---@param color string
---@param icon string
---@param text string
local function append_icon_and_text(elements, color, icon, text)
  if icon == '' and text == '' then
    return
  end

  table_insert(elements, { Foreground = { Color = color } })

  if icon ~= '' then
    table_insert(elements, { Text = icon })
  end

  if text ~= '' then
    if icon ~= '' then
      table_insert(elements, { Text = ' ' })
    end

    table_insert(elements, { Text = text })
  end

  table_insert(elements, { Text = ' ' })
end

---@param text string
---@param config WsWezResolvedConfig
---@return string
function M.format_action_label(text, config)
  local label = {}

  append_icon_and_text(
    label,
    config.colors.action_prefix,
    resolve_style_component(config.style.action),
    ''
  )
  table_insert(label, { Foreground = { Color = config.colors.text } })
  table_insert(label, { Text = text })

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
  local label = {}

  append_icon_and_text(
    label,
    colors.workspace_prefix,
    resolve_style_component(style.workspace),
    labels.workspace
  )
  table_insert(label, { Foreground = { Color = colors.text } })
  table_insert(label, { Text = name })

  table_insert(label, { Foreground = { Color = colors.path } })
  table_insert(label, { Attribute = { Intensity = 'Half' } })
  table_insert(label, { Text = ' (' })

  local pane_count_icon = resolve_style_component(style.pane_count)

  if pane_count_icon ~= '' then
    table_insert(label, { Text = pane_count_icon .. ' ' })
  end

  table_insert(label, { Text = tostring(pane_count) .. ')' })
  table_insert(label, { Attribute = { Intensity = 'Normal' } })

  if is_current then
    table_insert(label, { Text = ' ' })
    append_icon_and_text(
      label,
      colors.current_indicator,
      resolve_style_component(style.current),
      labels.current
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
  local label = {}

  append_icon_and_text(
    label,
    colors.zoxide_prefix,
    resolve_style_component(config.style.zoxide),
    labels.zoxide
  )
  table_insert(label, { Foreground = { Color = colors.text } })
  table_insert(label, { Text = Utils.basename(directory) .. ' ' })
  table_insert(label, { Foreground = { Color = colors.path } })
  table_insert(label, { Text = '(' .. directory .. ')' })

  return wezterm_format(label)
end

---@param saved_name string
---@param state WsWezSavedState|nil
---@param config WsWezResolvedConfig
---@return string
function M.format_saved_workspace_label(saved_name, state, config)
  local details = {}

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

  local label = {
    { Text = string_format(' %s ', saved_name) },
  }

  if #details > 0 then
    table_insert(label, { Foreground = { Color = config.colors.path } })
    table_insert(label, { Text = '(' .. table_concat(details, ' | ') .. ')' })
  end

  return wezterm_format(label)
end

return M
