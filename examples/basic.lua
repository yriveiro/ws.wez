-- Minimal setup through the supported public plugin facade.

local wezterm = require 'wezterm' ---@type Wezterm
local ws = wezterm.plugin.require 'https://github.com/yriveiro/ws.wez'

local config = wezterm.config_builder() ---@type Config

config.color_scheme = 'Tokyo Night'
config.font = wezterm.font 'JetBrains Mono'
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }

ws.apply_to_config(config)

return config
