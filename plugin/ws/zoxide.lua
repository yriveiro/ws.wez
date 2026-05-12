local wezterm = require 'wezterm' ---@type Wezterm

local Config = require 'ws.config'
local Utils = require 'ws.utils'

local M = {}

---@return string[]
function M.get_directories()
  local config = Config.get()
  local success, stdout, stderr = wezterm.run_child_process {
    config.zoxide_path,
    'query',
    '-l',
  }

  if not success then
    wezterm.log_warn 'ws: Failed to execute zoxide command'

    if stderr and stderr ~= '' then
      wezterm.log_warn(stderr)
    end

    return {}
  end

  local directories = {}

  for directory in stdout:gmatch '[^\r\n]+' do
    table.insert(directories, Utils.replace_home_with_tilde(directory, wezterm.home_dir))
  end

  return directories
end

return M
