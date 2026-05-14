-- Manual keybindings through the supported public plugin facade.

local wezterm = require 'wezterm' ---@type Wezterm
local ws = wezterm.plugin.require 'https://github.com/yriveiro/ws.wez'

local config = wezterm.config_builder() ---@type Config

config.color_scheme = 'Tokyo Night'
config.font = wezterm.font 'JetBrains Mono'
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }

ws.setup {
  activate_keytable = false,
  restore_on_gui_startup = false,
  zoxide_path = '/opt/homebrew/bin/zoxide',
  colors = {
    workspace_prefix = '#9ece6a',
    zoxide_prefix = '#f7768e',
    current_indicator = '#9ece6a',
    text = '#c8d0e0',
    path = '#565f89',
  },
}

config.keys = {
  {
    key = 'w',
    mods = 'LEADER',
    action = wezterm.action_callback(function(window, pane)
      ws.show_workspace_selector(window, pane)
    end),
  },
  {
    key = 'c',
    mods = 'LEADER',
    action = ws.create_workspace_manually(),
  },
  {
    key = 's',
    mods = 'LEADER',
    action = ws.save_current_workspace(),
  },
  {
    key = 'a',
    mods = 'LEADER',
    action = ws.save_all_workspaces(),
  },
  {
    key = 'e',
    mods = 'LEADER',
    action = ws.rename_workspace(),
  },
  {
    key = 'o',
    mods = 'LEADER',
    action = wezterm.action_callback(function(window, pane)
      ws.show_restore_menu(window, pane)
    end),
  },
  {
    key = 'd',
    mods = 'LEADER',
    action = wezterm.action_callback(function(window, pane)
      ws.show_delete_live_menu(window, pane)
    end),
  },
  {
    key = 'x',
    mods = 'LEADER',
    action = wezterm.action_callback(function(window, pane)
      ws.show_delete_saved_menu(window, pane)
    end),
  },
}

return config
