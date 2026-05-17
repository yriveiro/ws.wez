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

---@param parts string[]
---@param value string
local function append_part(parts, value)
  if type(value) ~= 'string' or value == '' then
    return
  end

  table_insert(parts, value)
end

---@param elements table[]
---@param color string
---@param parts string[]
local function append_row(elements, color, parts)
  if #parts == 0 then
    return
  end

  table_insert(elements, { Foreground = { Color = color } })
  table_insert(elements, { Text = table_concat(parts, ' ') })
end

---@param text string
---@param config WsWezResolvedConfig
---@return string
function M.format_action_label(text, config)
  local parts = {}
  local label = {}

  append_part(parts, join_icon_and_text(resolve_style_component(config.style.action), ''))
  append_part(parts, text)
  append_row(label, config.colors.action_prefix, parts)

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
  local parts = {}
  local pane_count_parts = {}
  local label = {}

  append_part(pane_count_parts, resolve_style_component(style.pane_count))
  append_part(pane_count_parts, tostring(pane_count))

  append_part(
    parts,
    join_icon_and_text(
      resolve_style_component(style.workspace),
      labels.workspace
    )
  )
  append_part(parts, name)
  append_part(parts, '(' .. table_concat(pane_count_parts, ' ') .. ')')
  if is_current then
    append_part(
      parts,
      join_icon_and_text(
        resolve_style_component(style.current),
        labels.current
      )
    )
  end

  append_row(label, is_current and colors.current_indicator or colors.workspace_prefix, parts)

  return wezterm_format(label)
end

---@param directory string
---@param config WsWezResolvedConfig
---@return string
function M.format_directory_label(directory, config)
  local parts = {}
  local label = {}

  append_part(
    parts,
    join_icon_and_text(
      resolve_style_component(config.style.zoxide),
      config.labels.zoxide
    )
  )
  append_part(parts, Utils.basename(directory))
  append_part(parts, '(' .. directory .. ')')
  append_row(label, config.colors.zoxide_prefix, parts)

  return wezterm_format(label)
end

---@param saved_name string
---@param state WsWezSavedState|nil
---@param config WsWezResolvedConfig
---@return string
function M.format_saved_workspace_label(saved_name, state, config)
  local details = {}
  local parts = {}
  local label = {}

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

  append_part(parts, saved_name)
  if #details > 0 then
    append_part(parts, '(' .. table_concat(details, ' | ') .. ')')
  end

  append_row(label, config.colors.text, parts)

  return wezterm_format(label)
end

return M
