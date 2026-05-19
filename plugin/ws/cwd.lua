local wezterm = require 'wezterm' ---@type Wezterm

local ipairs = ipairs
local pcall = pcall
local tonumber = tonumber
local type = type
local string_char = string.char

local is_windows = wezterm.target_triple:find 'windows' ~= nil
local mux_all_windows = wezterm.mux.all_windows

local M = {}

---@param text string
---@return string
local function decode_percent_encoded(text)
  local decoded = text:gsub('%%(%x%x)', function(hex)
    return string_char(tonumber(hex, 16))
  end)

  return decoded
end

---@param path string
---@return string|nil
local function normalize_file_path(path)
  if type(path) ~= 'string' or path == '' then
    return nil
  end

  path = decode_percent_encoded(path)

  if is_windows then
    path = path:gsub('^/([A-Za-z]:[/\\])', '%1'):gsub('/', '\\')
  end

  return path
end

---@param cwd string|Url|nil
---@return string|nil
function M.cwd_to_path(cwd)
  if type(cwd) ~= 'string' then
    local ok, text = pcall(tostring, cwd)

    if not ok or type(text) ~= 'string' or text == '' then
      return nil
    end

    cwd = text
  end

  if cwd == '' then
    return nil
  end

  if not cwd:match '^file://' then
    if cwd:match '^[%w+.-]+://' then
      return nil
    end

    return cwd
  end

  local path = cwd:match '^file://[^/]*(/.*)$'

  if not path or path == '' then
    return nil
  end

  return normalize_file_path(path)
end

---@param pane Pane|nil
---@return string|nil
local function get_pane_path(pane)
  if not pane then
    return nil
  end

  local ok, cwd = pcall(pane.get_current_working_dir, pane)

  if not ok then
    return nil
  end

  return M.cwd_to_path(cwd)
end

---@param mux_window MuxWindow
---@return Pane|nil
local function get_active_pane_for_mux_window(mux_window)
  local ok, pane = pcall(mux_window.active_pane, mux_window)

  if ok and pane then
    return pane
  end

  local ok_tabs, tabs_with_info = pcall(mux_window.tabs_with_info, mux_window)

  if not ok_tabs or type(tabs_with_info) ~= 'table' then
    return nil
  end

  for _, tab_info in ipairs(tabs_with_info) do
    if tab_info.is_active and tab_info.tab then
      local ok_panes, panes_with_info = pcall(tab_info.tab.panes_with_info, tab_info.tab)

      if ok_panes and type(panes_with_info) == 'table' then
        for _, pane_info in ipairs(panes_with_info) do
          if pane_info.is_active then
            return pane_info.pane
          end
        end
      end
    end
  end

  return nil
end

---@param workspace_name string
---@param preferred_pane Pane|nil
---@return string|nil
function M.get_workspace_path(workspace_name, preferred_pane)
  local preferred_path = get_pane_path(preferred_pane)

  if preferred_path then
    return preferred_path
  end

  for _, mux_window in ipairs(mux_all_windows() or {}) do
    local ok, window_workspace_name = pcall(mux_window.get_workspace, mux_window)

    if ok and window_workspace_name == workspace_name then
      local path = get_pane_path(get_active_pane_for_mux_window(mux_window))

      if path then
        return path
      end
    end
  end

  return nil
end

---@param preferred_workspace_name string|nil
---@param preferred_pane Pane|nil
---@return table<string, string>
function M.get_workspace_paths(preferred_workspace_name, preferred_pane)
  local workspace_paths = {}
  local preferred_path = get_pane_path(preferred_pane)

  if
    type(preferred_workspace_name) == 'string'
    and preferred_workspace_name ~= ''
    and preferred_path
  then
    workspace_paths[preferred_workspace_name] = preferred_path
  end

  for _, mux_window in ipairs(mux_all_windows() or {}) do
    local ok, workspace_name = pcall(mux_window.get_workspace, mux_window)

    if
      ok
      and type(workspace_name) == 'string'
      and workspace_name ~= ''
      and not workspace_paths[workspace_name]
    then
      local path = get_pane_path(get_active_pane_for_mux_window(mux_window))

      if path then
        workspace_paths[workspace_name] = path
      end
    end
  end

  return workspace_paths
end

return M
