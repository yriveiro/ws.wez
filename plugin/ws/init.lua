local wezterm = require 'wezterm' ---@type Wezterm

require 'ws.types'

local Actions = require 'ws.actions'
local Config = require 'ws.config'
local Selectors = require 'ws.selectors'
local State = require 'ws.state'

---@type WorkspacePicker
local M = {}

---@param cmd? SpawnCommand
function M.restore_workspaces_on_gui_startup(cmd)
  if not Config.get().restore_on_gui_startup then
    return
  end

  local state = State.get_global_state()

  if state.restore_attempted_on_gui_startup then
    return
  end

  state.restore_attempted_on_gui_startup = true

  local result = State.restore_saved_workspaces { cmd = cmd }

  if result.found == 0 then
    wezterm.log_info 'ws: No saved workspaces found for startup restore'
    return
  end

  local summary = Actions.format_restore_summary(result, 'created')

  if #result.failed == 0 then
    wezterm.log_info('ws: Startup restore ' .. summary)
    return
  end

  wezterm.log_warn('ws: Startup restore ' .. summary)
end

---@param opts? WorkspacePickerConfig
---@return WorkspacePicker
function M.setup(opts)
  Config.setup(M.restore_workspaces_on_gui_startup, opts)

  return M
end

---@param window Window
---@param pane Pane
function M.show_workspace_selector(window, pane)
  Selectors.show_workspace_selector(window, pane, {
    save_all_workspaces = M.save_all_workspaces,
    show_delete_menu = M.show_delete_menu,
    create_workspace_manually = M.create_workspace_manually,
    rename_workspace = M.rename_workspace,
  })
end

---@return Action
function M.rename_workspace()
  return Actions.rename_workspace()
end

---@return Action
function M.create_workspace_manually()
  return Actions.create_workspace_manually()
end

---@return Action
function M.save_workspace()
  return Actions.save_workspace()
end

---@return Action
function M.save_all_workspaces()
  return Actions.save_all_workspaces()
end

---@return Action
function M.restore_all_workspaces()
  return Actions.restore_all_workspaces()
end

---@param window Window
---@param pane Pane
function M.show_restore_menu(window, pane)
  Selectors.show_restore_menu(window, pane)
end

---@param window Window
---@param pane Pane
function M.show_delete_menu(window, pane)
  Selectors.show_delete_menu(window, pane)
end

---@param config Config
---@param opts? WorkspacePickerConfig
---@return Config
function M.apply_to_config(config, opts)
  local cfg = Config.apply(M.restore_workspaces_on_gui_startup, opts)

  config.keys = config.keys or {}

  if not cfg.activate_keytable then
    return config
  end

  local filtered_keys = {}

  for _, binding in ipairs(config.keys) do
    if
      binding.mods ~= cfg.activate_keytable.mods
      or binding.key ~= cfg.activate_keytable.key
    then
      table.insert(filtered_keys, binding)
    end
  end

  table.insert(filtered_keys, {
    mods = cfg.activate_keytable.mods,
    key = cfg.activate_keytable.key,
    action = wezterm.action_callback(function(window, pane)
      M.show_workspace_selector(window, pane)
    end),
  })

  config.keys = filtered_keys

  return config
end

function M.get_data_dir()
  return State.get_data_dir()
end

return M
