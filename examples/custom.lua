-- Compact customization through the supported public plugin facade.

local wezterm = require 'wezterm' ---@type Wezterm
local ws = wezterm.plugin.require 'https://github.com/yriveiro/ws.wez'

local config = wezterm.config_builder() ---@type Config

config.color_scheme = 'Catppuccin Mocha'
config.font = wezterm.font 'JetBrains Mono'
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }

ws.apply_to_config(config, {
  zoxide_path = '/opt/homebrew/bin/zoxide',
  restore_on_gui_startup = true,
  activate_keytable = { mods = 'LEADER', key = 'w' },
  colors = {
    action_prefix = '#89ddff',
    workspace_prefix = '#a6e3a1',
    zoxide_prefix = '#f38ba8',
    current_indicator = '#a6e3a1',
    text = '#cdd6f4',
    path = '#6c7086',
  },
  labels = {
    workspace = '',
    zoxide = '',
    current = '',
  },
  style = {
    action = 'seti_config',
    current = 'pl_right_hard_divider',
    pane_count = 'cod_library',
    workspace = 'md_television_guide',
    zoxide = 'oct_file_directory_fill',
  },
})

return config
