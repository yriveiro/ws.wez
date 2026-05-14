local wezterm = require 'wezterm' ---@type Wezterm

local os_time = os.time
local table_insert = table.insert

local home_dir = wezterm.home_dir

local Config = require 'ws.config'
local Utils = require 'ws.utils'

local M = {}

local cache_ttl_seconds = 5
local cached_at = 0
local cached_directories = {}
local cached_zoxide_path

---@param config WsWezResolvedConfig
---@return boolean
local function is_cache_valid(config)
  return cached_zoxide_path == config.zoxide_path
    and os_time() - cached_at < cache_ttl_seconds
end

---@return string[]
function M.get_directories()
  local config = Config.get()

  if is_cache_valid(config) then
    return cached_directories
  end

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

    cached_at = os_time()
    cached_directories = {}
    cached_zoxide_path = config.zoxide_path

    return cached_directories
  end

  local directories = {}

  for directory in stdout:gmatch '[^\r\n]+' do
    table_insert(directories, Utils.replace_home_with_tilde(directory, home_dir))
  end

  cached_at = os_time()
  cached_directories = directories
  cached_zoxide_path = config.zoxide_path

  return cached_directories
end

return M
