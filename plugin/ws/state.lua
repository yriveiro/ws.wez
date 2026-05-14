local wezterm = require 'wezterm' ---@type Wezterm

local io_open = io.open
local ipairs = ipairs
local load = load
local os_getenv = os.getenv
local pairs = pairs
local pcall = pcall
local table_concat = table.concat
local table_insert = table.insert
local table_sort = table.sort
local tonumber = tonumber
local tostring = tostring
local type = type
local string_format = string.format

local is_windows = wezterm.target_triple:find 'windows' ~= nil
local mux = wezterm.mux
local mux_all_windows = wezterm.mux.all_windows
local mux_set_active_workspace = wezterm.mux.set_active_workspace
local mux_spawn_window = wezterm.mux.spawn_window

---@class WsWezLoadedChunk
---@return WsWezSavedWorkspaceIndex

local Cwd = require 'ws.cwd'

local M = {}
local ensured_directories = {}

---@return string
function M.get_data_dir()
  local xdg_data = os_getenv 'XDG_DATA_HOME'

  if xdg_data and xdg_data ~= '' then
    return xdg_data .. '/ws'
  end

  return wezterm.home_dir .. '/.local/share/ws'
end

local function workspace_state_index_dir()
  return M.get_data_dir() .. '/state'
end

---@return string
local function workspace_state_index_path()
  return workspace_state_index_dir() .. '/saved-workspaces.lua'
end

---@return string
local function wezterm_executable_path()
  local executable = is_windows and 'wezterm.exe' or 'wezterm'

  if type(wezterm.executable_dir) == 'string' and wezterm.executable_dir ~= '' then
    local separator = is_windows and '\\' or '/'

    return wezterm.executable_dir .. separator .. executable
  end

  return executable
end

---@param args string[]
---@return boolean, string, string
local function run_wezterm_cli(args)
  local command = { wezterm_executable_path() }

  for _, arg in ipairs(args) do
    table_insert(command, arg)
  end

  local ok, stdout, stderr = wezterm.run_child_process(command)

  return ok, stdout or '', stderr or ''
end

---@return WsWezGlobalState
function M.get_global_state()
  wezterm.GLOBAL.ws = wezterm.GLOBAL.ws or {}

  ---@type WsWezGlobalState
  return wezterm.GLOBAL.ws
end

---@param workspace_name unknown
---@return boolean
local function is_valid_workspace_name(workspace_name)
  return type(workspace_name) == 'string' and workspace_name ~= ''
end

---@param state WsWezSavedState|nil
---@return WsWezSavedState
local function normalize_workspace_state(state)
  state = state or {}

  local normalized = {
    timestamp = tonumber(state.timestamp) or 0,
  }

  if type(state.cwd) == 'string' and state.cwd ~= '' then
    normalized.cwd = state.cwd
  end

  return normalized
end

---@param saved_workspaces WsWezSavedWorkspaceIndex
---@return string
local function serialize_saved_workspaces(saved_workspaces)
  local lines = {
    'return {',
  }

  local workspace_names = {}

  for workspace_name in pairs(saved_workspaces) do
    table_insert(workspace_names, workspace_name)
  end

  table_sort(workspace_names)

  for _, workspace_name in ipairs(workspace_names) do
    local state = normalize_workspace_state(saved_workspaces[workspace_name])

    table_insert(lines, string_format('  [%q] = {', workspace_name))

    if type(state.cwd) == 'string' and state.cwd ~= '' then
      table_insert(lines, string_format('    cwd = %q,', state.cwd))
    end

    table_insert(
      lines,
      string_format('    timestamp = %d,', tonumber(state.timestamp) or 0)
    )
    table_insert(lines, '  },')
  end

  table_insert(lines, '}')

  return table_concat(lines, '\n') .. '\n'
end

---@param file_path string
---@return string|nil
local function read_file_contents(file_path)
  local file = io_open(file_path, 'r')

  if not file then
    return nil
  end

  local content = file:read '*a'

  file:close()

  if content == '' then
    return nil
  end

  return content
end

---@param content string
---@param file_path string
---@return WsWezSavedWorkspaceIndex|nil
local function load_lua_workspace_state(content, file_path)
  local chunk = load(content, '@' .. file_path, 't', {}) ---@type WsWezLoadedChunk|nil

  if not chunk then
    return nil
  end

  local ok, state = pcall(chunk)

  if not ok or type(state) ~= 'table' then
    return nil
  end

  return state
end

---@return WsWezSavedWorkspaceIndex
local function load_saved_workspaces()
  local content = read_file_contents(workspace_state_index_path())

  if not content then
    return {}
  end

  local state = load_lua_workspace_state(content, workspace_state_index_path())

  if type(state) ~= 'table' then
    return {}
  end

  local saved_workspaces = {}

  for workspace_name, workspace_state in pairs(state) do
    if type(workspace_name) == 'string' and type(workspace_state) == 'table' then
      saved_workspaces[workspace_name] = normalize_workspace_state(workspace_state)
    end
  end

  return saved_workspaces
end

---@return WsWezSavedWorkspaceIndex
M.load_saved_workspaces = load_saved_workspaces

---@param directory_path string
---@return boolean
local function ensure_directory(directory_path)
  if directory_path == '' then
    return false
  end

  if ensured_directories[directory_path] then
    return true
  end

  if is_windows then
    local command = string_format(
      "New-Item -ItemType Directory -Force -LiteralPath '%s' | Out-Null",
      directory_path:gsub("'", "''")
    )
    local ok = wezterm.run_child_process {
      'powershell.exe',
      '-NoProfile',
      '-Command',
      command,
    }

    if ok then
      ensured_directories[directory_path] = true
    end

    return ok
  end

  local ok = wezterm.run_child_process { 'mkdir', '-p', directory_path }

  if ok then
    ensured_directories[directory_path] = true
  end

  return ok
end

---@return boolean
local function ensure_workspace_state_directories()
  return ensure_directory(M.get_data_dir())
    and ensure_directory(workspace_state_index_dir())
end

---@param saved_workspaces WsWezSavedWorkspaceIndex
---@return boolean
local function write_saved_workspaces(saved_workspaces)
  if not ensure_workspace_state_directories() then
    return false
  end

  local file_path = workspace_state_index_path()
  local file = io_open(file_path, 'w')

  if not file then
    ensured_directories[M.get_data_dir()] = nil
    ensured_directories[workspace_state_index_dir()] = nil

    if not ensure_workspace_state_directories() then
      return false
    end

    file = io_open(file_path, 'w')

    if not file then
      return false
    end
  end

  local serialized = serialize_saved_workspaces(saved_workspaces)
  local ok = file:write(serialized)

  file:close()

  return ok ~= nil
end

---@return table[]|nil, string|nil
local function load_live_workspace_panes()
  local ok, stdout, stderr = run_wezterm_cli { 'cli', 'list', '--format=json' }

  if not ok then
    return nil, stderr ~= '' and stderr or 'failed to execute wezterm cli list'
  end

  local parsed_ok, panes = pcall(wezterm.json_parse, stdout)

  if not parsed_ok or type(panes) ~= 'table' then
    return nil, 'failed to parse wezterm cli list output'
  end

  return panes, nil
end

---@param pane_id integer
---@return boolean, string|nil
local function kill_pane(pane_id)
  local ok, _, stderr = run_wezterm_cli {
    'cli',
    'kill-pane',
    '--pane-id',
    tostring(pane_id),
  }

  if not ok then
    return false, stderr ~= '' and stderr or ('failed to kill pane ' .. tostring(pane_id))
  end

  return true, nil
end

---@param workspace_name string
---@param state WsWezSavedState|nil
---@return boolean
function M.save_workspace_state(workspace_name, state)
  if not is_valid_workspace_name(workspace_name) then
    return false
  end

  local saved_workspaces = load_saved_workspaces()

  saved_workspaces[workspace_name] = normalize_workspace_state(state)

  return write_saved_workspaces(saved_workspaces)
end

---@param workspace_states WsWezSavedWorkspaceIndex
---@return boolean
function M.save_workspace_states(workspace_states)
  local saved_workspaces = load_saved_workspaces()

  for workspace_name, state in pairs(workspace_states) do
    if is_valid_workspace_name(workspace_name) then
      saved_workspaces[workspace_name] = normalize_workspace_state(state)
    end
  end

  return write_saved_workspaces(saved_workspaces)
end

---@param workspace_name string
---@return boolean
function M.delete_workspace_state(workspace_name)
  if not is_valid_workspace_name(workspace_name) then
    return false
  end

  local saved_workspaces = load_saved_workspaces()

  saved_workspaces[workspace_name] = nil

  return write_saved_workspaces(saved_workspaces)
end

---@param pane_id integer
---@return boolean
function M.kill_pane_later(pane_id)
  if type(pane_id) ~= 'number' then
    return false
  end

  wezterm.background_child_process {
    wezterm_executable_path(),
    'cli',
    'kill-pane',
    '--pane-id',
    tostring(pane_id),
  }

  return true
end

---@param workspace_name string
---@param opts? { current_pane_id?: integer, defer_current_pane?: boolean }
---@return boolean, { deferred_pane_id: integer|nil }|string
function M.delete_live_workspace(workspace_name, opts)
  opts = opts or {}

  if not is_valid_workspace_name(workspace_name) then
    return false, 'invalid workspace name'
  end

  local panes, err = load_live_workspace_panes()

  if not panes then
    return false, err or 'failed to load live workspaces'
  end

  local pane_ids = {}
  local deferred_pane_id
  local trailing_pane_id

  for _, pane_info in ipairs(panes) do
    local pane_id = tonumber(type(pane_info) == 'table' and pane_info.pane_id or nil)

    if
      pane_id
      and type(pane_info.workspace) == 'string'
      and pane_info.workspace == workspace_name
    then
      if opts.current_pane_id and pane_id == opts.current_pane_id then
        if opts.defer_current_pane then
          deferred_pane_id = pane_id
        else
          trailing_pane_id = pane_id
        end
      else
        table_insert(pane_ids, pane_id)
      end
    end
  end

  if trailing_pane_id then
    table_insert(pane_ids, trailing_pane_id)
  end

  for _, pane_id in ipairs(pane_ids) do
    local ok, kill_err = kill_pane(pane_id)

    if not ok then
      return false, kill_err or ('failed to delete workspace ' .. workspace_name)
    end
  end

  return true, {
    deferred_pane_id = deferred_pane_id,
  }
end

---@return table<string, boolean>
function M.get_restored_workspaces()
  local restored = {}

  for _, mux_window in ipairs(mux_all_windows() or {}) do
    local ok, workspace_name = pcall(mux_window.get_workspace, mux_window)

    if ok and type(workspace_name) == 'string' and workspace_name ~= '' then
      restored[workspace_name] = true
    end
  end

  return restored
end

---@param spawn_args WsWezSpawnWindowArgs
---@param cmd SpawnCommand|nil
local function merge_spawn_command(spawn_args, cmd)
  if not cmd then
    return
  end

  if cmd.args then
    spawn_args.args = cmd.args
  end

  if not spawn_args.cwd and cmd.cwd then
    spawn_args.cwd = Cwd.cwd_to_path(cmd.cwd) or cmd.cwd
  end

  if cmd.set_environment_variables then
    spawn_args.set_environment_variables = cmd.set_environment_variables
  end

  if cmd.domain then
    spawn_args.domain = cmd.domain
  end

  if cmd.position then
    spawn_args.position = cmd.position
  end

  if cmd.width and cmd.height then
    spawn_args.width = cmd.width
    spawn_args.height = cmd.height
  end
end

---@param opts WsWezRestoreOptions|nil
---@return WsWezRestoreResult
function M.restore_saved_workspaces(opts)
  opts = opts or {}

  local saved_workspaces = load_saved_workspaces()
  local saved = {}

  for workspace_name in pairs(saved_workspaces) do
    table_insert(saved, workspace_name)
  end

  if #saved == 0 then
    return {
      found = 0,
      restored = 0,
      skipped = 0,
      failed = {},
      first_restored_workspace = nil,
    }
  end

  local existing = M.get_restored_workspaces()

  table_sort(saved)

  local restored = 0
  local skipped = 0
  local failed = {}
  local first_restored_workspace
  local startup_cmd_consumed = false

  for _, workspace_name in ipairs(saved) do
    local state = saved_workspaces[workspace_name] or {}

    if existing[workspace_name] then
      skipped = skipped + 1
    else
      ---@type WsWezSpawnWindowArgs
      local spawn_args = {
        workspace = workspace_name,
      }

      if type(state.cwd) == 'string' and state.cwd ~= '' then
        spawn_args.cwd = state.cwd
      end

      if opts.cmd and not startup_cmd_consumed then
        merge_spawn_command(spawn_args, opts.cmd)
      end

      local ok, result = pcall(mux_spawn_window, spawn_args)

      if ok then
        restored = restored + 1
        existing[workspace_name] = true
        startup_cmd_consumed = startup_cmd_consumed or opts.cmd ~= nil

        if not first_restored_workspace then
          first_restored_workspace = workspace_name
        end
      else
        table_insert(failed, workspace_name)
        wezterm.log_warn(
          "ws: Failed to restore workspace '"
            .. workspace_name
            .. "': "
            .. tostring(result)
        )
      end
    end
  end

  if first_restored_workspace then
    pcall(mux_set_active_workspace, first_restored_workspace)
  end

  return {
    found = #saved,
    restored = restored,
    skipped = skipped,
    failed = failed,
    first_restored_workspace = first_restored_workspace,
  }
end

return M
