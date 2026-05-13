local wezterm = require 'wezterm' ---@type Wezterm
local act = wezterm.action

local Utils = require 'ws.utils'

local M = {}

local selector_alphabet = 'wsdce1234567890abrfghilmnoptuvxyz'
local selector_separator =
  '─────────────────────────────────────────────────────────'
local no_saved_workspaces_body =
  'No saved workspaces found. Open the selector, then press s.'

---@param window Window
---@param title string
---@param body string
function M.notify(window, title, body)
  window:toast_notification(title, body)
end

---@param window Window
function M.notify_no_saved_workspaces(window)
  M.notify(window, 'No Saved Workspaces', no_saved_workspaces_body)
end

---@param window Window
---@param pane Pane
---@param opts WorkspacePickerInputSelectorOpts
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
---@param config WorkspacePickerResolvedConfig
---@return string
function M.format_live_workspace_label(name, is_current, config)
  local colors = config.colors
  local labels = config.labels
  local label = {
    { Foreground = { Color = colors.workspace_prefix } },
    { Text = labels.workspace },
    { Foreground = { Color = colors.text } },
    { Text = string.format(is_current and ' %-30s ' or ' %s ', name) },
  }

  if is_current then
    table.insert(label, { Foreground = { Color = colors.current_indicator } })
    table.insert(label, { Text = labels.current })
  end

  return wezterm.format(label)
end

---@param directory string
---@param config WorkspacePickerResolvedConfig
---@return string
function M.format_directory_label(directory, config)
  local colors = config.colors
  local labels = config.labels

  return wezterm.format {
    { Foreground = { Color = colors.zoxide_prefix } },
    { Text = labels.zoxide },
    { Foreground = { Color = colors.text } },
    { Text = ' ' .. Utils.basename(directory) .. ' ' },
    { Foreground = { Color = colors.path } },
    { Text = '(' .. directory .. ')' },
  }
end

---@param saved_name string
---@param state WorkspacePickerSavedState|nil
---@param config WorkspacePickerResolvedConfig
---@return string
function M.format_saved_workspace_label(saved_name, state, config)
  local details = {}

  if
    type(state) == 'table'
    and type(state.timestamp) == 'number'
    and state.timestamp > 0
  then
    table.insert(details, os.date('%Y-%m-%d %H:%M', state.timestamp))
  end

  if type(state) == 'table' and type(state.cwd) == 'string' and state.cwd ~= '' then
    table.insert(details, state.cwd)
  end

  local label = {
    { Text = string.format(' %s ', saved_name) },
  }

  if #details > 0 then
    table.insert(label, { Foreground = { Color = config.colors.path } })
    table.insert(label, { Text = '(' .. table.concat(details, ' | ') .. ')' })
  end

  return wezterm.format(label)
end

return M
