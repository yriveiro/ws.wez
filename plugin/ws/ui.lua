local wezterm = require 'wezterm' ---@type Wezterm
local act = wezterm.action

local os_date = os.date
local string_format = string.format
local table_concat = table.concat
local table_insert = table.insert
local type = type

local wezterm_format = wezterm.format

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

---@param name string
---@param is_current boolean
---@param config WsWezResolvedConfig
---@return string
function M.format_live_workspace_label(name, is_current, config)
  local colors = config.colors
  local labels = config.labels
  local label = {
    { Foreground = { Color = colors.workspace_prefix } },
    { Text = labels.workspace },
    { Foreground = { Color = colors.text } },
    { Text = string_format(is_current and ' %-30s ' or ' %s ', name) },
  }

  if is_current then
    table_insert(label, { Foreground = { Color = colors.current_indicator } })
    table_insert(label, { Text = labels.current })
  end

  return wezterm_format(label)
end

---@param directory string
---@param config WsWezResolvedConfig
---@return string
function M.format_directory_label(directory, config)
  local colors = config.colors
  local labels = config.labels

  return wezterm_format {
    { Foreground = { Color = colors.zoxide_prefix } },
    { Text = labels.zoxide },
    { Foreground = { Color = colors.text } },
    { Text = ' ' .. Utils.basename(directory) .. ' ' },
    { Foreground = { Color = colors.path } },
    { Text = '(' .. directory .. ')' },
  }
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
