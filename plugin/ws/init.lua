local wezterm = require 'wezterm' ---@type Wezterm

require 'ws.types'

local Actions = require 'ws.actions'
local Config = require 'ws.config'
local Selectors = require 'ws.selectors'
local State = require 'ws.state'

---@type WsWezPlugin
local M = {
  create_workspace_manually = Actions.create_workspace_manually,
  get_data_dir = State.get_data_dir,
  rename_workspace = Actions.rename_workspace,
  restore_all_workspaces = Actions.restore_all_workspaces,
  save_all_workspaces = Actions.save_all_workspaces,
  save_current_workspace = Actions.save_current_workspace,
  save_workspace_as = Actions.save_workspace,
  show_delete_live_menu = Selectors.show_delete_live_menu,
  show_delete_saved_menu = Selectors.show_delete_saved_menu,
  show_restore_menu = Selectors.show_restore_menu,
}

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

---@param opts? WsWezConfig
---@return WsWezPlugin
function M.setup(opts)
  Config.setup(M.restore_workspaces_on_gui_startup, opts)

  return M
end

---@param window Window
---@param pane Pane
function M.show_workspace_selector(window, pane)
  Selectors.show_workspace_selector(window, pane, M)
end

---@param config Config
---@param opts? WsWezConfig
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

M.save_workspace = M.save_workspace_as
M.show_delete_menu = M.show_delete_live_menu

return M
