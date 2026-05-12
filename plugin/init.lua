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

local NAME = 'httpssCssZssZsgithubsDscomsZsyriveirosZswsDswez'

local wezterm = require 'wezterm' ---@type Wezterm

-- Prepare for loading submodules inside the plugin. WezTerm doesn't handle
-- this natively.
local separator = wezterm.target_triple:match 'windows' and '\\' or '/'
local root_path = wezterm.plugin.list()[1].plugin_dir:match('(.*)' .. separator)
  .. separator
  .. NAME
  .. separator
  .. 'plugin'
  .. separator

package.path = package.path
  .. ';'
  .. root_path
  .. '?.lua'
  .. ';'
  .. root_path
  .. '?/init.lua'

return require 'ws'
