---@meta

--[[
@module 'ws'
@description A module for managing and switching between workspaces in WezTerm.
It provides a workspace picker that allows users to switch between live workspaces,
create new workspaces from zoxide directories, and persist workspace state for later restore.

@example Basic usage:
```lua
wezterm.plugin
  .require('https://github.com/yriveiro/ws.wez')
  .apply_to_config(config)
```
]]

local wezterm = require 'wezterm' ---@type Wezterm

local NAME = 'httpssCssZssZsgithubsDscomsZsyriveirosZswsDswez'

local separator = wezterm.target_triple:match 'windows' and '\\' or '/'

---@param path string|nil
---@return string|nil
local function dirname(path)
  if type(path) ~= 'string' or path == '' then
    return nil
  end

  return path:match '^(.*[/\\])'
end

---@return string
local function resolve_plugin_root()
  local first_plugin = wezterm.plugin.list()[1]

  if first_plugin and type(first_plugin.plugin_dir) == 'string' then
    local plugins_root = first_plugin.plugin_dir:match('(.*)' .. separator)

    if plugins_root then
      return plugins_root .. separator .. NAME .. separator .. 'plugin' .. separator
    end
  end

  local source = debug.getinfo(1, 'S').source
  local current_file = type(source) == 'string' and source:match '^@(.+)$'
  local current_dir = dirname(current_file)

  if current_dir then
    return current_dir
  end

  error("ws: Failed to resolve plugin directory for '" .. NAME .. "'")
end

---@param root_path string
local function add_package_path(root_path)
  local patterns = {
    root_path .. '?.lua',
    root_path .. '?/init.lua',
  }

  for _, pattern in ipairs(patterns) do
    if not package.path:find(pattern, 1, true) then
      package.path = pattern .. ';' .. package.path
    end
  end
end

add_package_path(resolve_plugin_root())

return require 'ws'
