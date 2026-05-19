local wezterm = require 'wezterm' ---@type Wezterm
local act = wezterm.action

local ipairs = ipairs
local os_time = os.time
local string_format = string.format
local table_concat = table.concat
local table_insert = table.insert
local type = type

local mux = wezterm.mux

local Cwd = require 'ws.cwd'
local State = require 'ws.state'
local UI = require 'ws.ui'

local M = {}

---@param value unknown
---@return boolean
local function has_text(value)
  return type(value) == 'string' and value ~= ''
end

---@param workspace_name string
---@param pane Pane|nil
---@param timestamp integer|nil
---@return WsWezSavedState|nil
local function build_save_state(workspace_name, pane, timestamp)
  local cwd = Cwd.get_workspace_path(workspace_name, pane)

  if not cwd then
    return nil
  end

  return {
    cwd = cwd,
    timestamp = timestamp or os_time(),
  }
end

---@param window Window
---@param workspace_name string
---@param save_state WsWezSavedState|nil
---@return boolean
local function persist_workspace_state(window, workspace_name, save_state)
  if not save_state then
    wezterm.log_warn(
      "ws: Failed to capture cwd for workspace state '" .. workspace_name .. "'"
    )
    UI.notify(
      window,
      'Workspace State Save Failed',
      "Failed to capture cwd for workspace state '" .. workspace_name .. "'."
    )

    return false
  end

  if not State.save_workspace_state(workspace_name, save_state) then
    wezterm.log_warn("ws: Failed to save workspace state '" .. workspace_name .. "'")
    UI.notify(
      window,
      'Workspace State Save Failed',
      "Failed to save workspace state '" .. workspace_name .. "'."
    )

    return false
  end

  wezterm.log_info("ws: Saved workspace state '" .. workspace_name .. "'")

  local path_msg = ' at ' .. save_state.cwd

  UI.notify(
    window,
    'Workspace State Saved',
    "Saved workspace state '" .. workspace_name .. "'" .. path_msg
  )

  return true
end

---@param result WsWezRestoreResult
---@param verb string|nil
---@return string
function M.format_restore_summary(result, verb)
  local summary = (verb or 'Restored') .. ' ' .. result.restored .. ' workspaces'

  if result.skipped > 0 then
    summary = summary .. ' (' .. result.skipped .. ' already existed)'
  end

  if #result.failed > 0 then
    summary = summary .. ', failed for: ' .. table_concat(result.failed, ', ')
  end

  return summary
end

---@return Action
function M.rename_workspace()
  return act.PromptInputLine {
    description = '(wezterm) Rename workspace title: ',
    action = wezterm.action_callback(function(_, _, line)
      if not has_text(line) then
        return
      end

      mux.rename_workspace(mux.get_active_workspace(), line)
    end),
  }
end

---@return Action
function M.create_workspace_manually()
  return act.PromptInputLine {
    description = '(wezterm) Create new workspace: ',
    action = wezterm.action_callback(function(window, pane, line)
      if not has_text(line) then
        return
      end

      window:perform_action(
        act.SwitchToWorkspace {
          name = line,
        },
        pane
      )
    end),
  }
end

---@return Action
function M.save_workspace()
  return act.PromptInputLine {
    description = '(wezterm) Save current workspace state as: ',
    action = wezterm.action_callback(function(window, pane, line)
      if not has_text(line) then
        return
      end

      local active_workspace = mux.get_active_workspace()
      local save_state = build_save_state(active_workspace, pane)
      persist_workspace_state(window, line, save_state)
    end),
  }
end

---@return Action
function M.save_current_workspace()
  return wezterm.action_callback(function(window, pane)
    local active_workspace = mux.get_active_workspace()
    local save_state = build_save_state(active_workspace, pane)
    persist_workspace_state(window, active_workspace, save_state)
  end)
end

---@return Action
function M.save_all_workspaces()
  return wezterm.action_callback(function(window, pane)
    local workspace_names = mux.get_workspace_names()
    local active_workspace = mux.get_active_workspace()
    local workspace_paths = Cwd.get_workspace_paths(active_workspace, pane)

    local timestamp = os_time()
    local workspace_states = {}
    local unsaved = {}

    for _, workspace_name in ipairs(workspace_names) do
      local cwd = workspace_paths[workspace_name]

      if cwd then
        workspace_states[workspace_name] = {
          cwd = cwd,
          timestamp = timestamp,
        }
      else
        table_insert(unsaved, workspace_name)
      end
    end

    local saved = #workspace_names - #unsaved

    if saved == 0 then
      local summary = 'Failed to capture cwd for: ' .. table_concat(unsaved, ', ')

      wezterm.log_warn('ws: ' .. summary)
      UI.notify(window, 'Workspace State Save Failed', summary)
      return
    end

    if State.save_workspace_states(workspace_states) then
      local message = 'Saved workspace state for ' .. saved .. ' workspaces.'

      if #unsaved > 0 then
        message = message .. ' Skipped: ' .. table_concat(unsaved, ', ') .. '.'
        wezterm.log_warn('ws: ' .. message)
        UI.notify(window, 'Workspace State Save Completed With Errors', message)
        return
      end

      wezterm.log_info('ws: ' .. message)
      UI.notify(window, 'Workspace States Saved', message)
      return
    end

    local summary = string_format(
      'Saved workspace state for %d workspaces, failed for: %s',
      0,
      table_concat(workspace_names, ', ')
    )

    wezterm.log_warn('ws: ' .. summary)
    UI.notify(window, 'Workspace State Save Completed With Errors', summary)
  end)
end

---@return Action
function M.restore_all_workspaces()
  return wezterm.action_callback(function(window, _)
    local result = State.restore_saved_workspaces()

    if result.found == 0 then
      UI.notify_no_saved_workspaces(window)
      return
    end

    local summary = M.format_restore_summary(result, 'Restored')

    if #result.failed == 0 then
      wezterm.log_info('ws: ' .. summary)
      UI.notify(window, 'Workspaces Restored', summary .. '.')
      return
    end

    wezterm.log_warn('ws: ' .. summary)
    UI.notify(window, 'Workspace Restore Completed With Errors', summary)
  end)
end

return M
