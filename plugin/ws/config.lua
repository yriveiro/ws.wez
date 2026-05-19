local wezterm = require 'wezterm' ---@type Wezterm

local Utils = require 'ws.utils'

local M = {}

---@type WsWezResolvedConfig
local default_config = {
  zoxide_path = '/opt/homebrew/bin/zoxide',
  restore_on_gui_startup = true,
  colors = {
    action_prefix = '#7dcfff',
    workspace_prefix = '#9ece6a',
    zoxide_prefix = '#f7768e',
    current_indicator = '#9ece6a',
    pane_count = '#ff9e64',
    text = '#c8d0e0',
    path = '#565f89',
    separator = '#6c7086',
  },
  labels = {
    workspace = '',
    zoxide = '',
    current = '',
  },
  style = {
    action = 'seti_config',
    current = 'cod_rocket',
    pane_count = 'cod_library',
    workspace = 'md_television_guide',
    zoxide = 'oct_file_directory_fill',
  },
  activate_keytable = { mods = 'LEADER', key = 'w' },
}

---@type WsWezResolvedConfig|nil
local user_config
local gui_startup_restore_registered = false

---@param handler fun(cmd?: SpawnCommand)
local function register_gui_startup(handler)
  if gui_startup_restore_registered then
    return
  end

  gui_startup_restore_registered = true
  wezterm.on('gui-startup', handler)
end

---@param opts? WsWezConfig
---@return WsWezResolvedConfig
local function merge(opts)
  local merged = Utils.table_merge({}, default_config)

  return Utils.table_merge(merged, opts or {})
end

---@return WsWezResolvedConfig
function M.get()
  return user_config or default_config
end

---@param handler fun(cmd?: SpawnCommand)
---@param opts? WsWezConfig
---@return WsWezResolvedConfig
function M.setup(handler, opts)
  user_config = merge(opts)

  if user_config.restore_on_gui_startup then
    register_gui_startup(handler)
  end

  return user_config
end

---@param handler fun(cmd?: SpawnCommand)
---@param opts? WsWezConfig
---@return WsWezResolvedConfig
function M.apply(handler, opts)
  if opts then
    return M.setup(handler, opts)
  end

  local config = M.get()

  if config.restore_on_gui_startup then
    register_gui_startup(handler)
  end

  return config
end

return M
