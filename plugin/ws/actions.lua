local wezterm = require 'wezterm' ---@type Wezterm
local act = wezterm.action

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
---@return WorkspacePickerSavedState
local function build_save_state(workspace_name, pane, timestamp)
  return {
    cwd = Cwd.get_workspace_path(workspace_name, pane),
    timestamp = timestamp or os.time(),
  }
end

---@param result WorkspacePickerRestoreResult
---@param verb string|nil
---@return string
function M.format_restore_summary(result, verb)
  local summary = (verb or 'Restored') .. ' ' .. result.restored .. ' workspaces'

  if result.skipped > 0 then
    summary = summary .. ' (' .. result.skipped .. ' already existed)'
  end

  if #result.failed > 0 then
    summary = summary .. ', failed for: ' .. table.concat(result.failed, ', ')
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

      wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
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
    description = '(wezterm) Save workspace as: ',
    action = wezterm.action_callback(function(window, pane, line)
      if not has_text(line) then
        return
      end

      local active_workspace = wezterm.mux.get_active_workspace()
      local save_state = build_save_state(active_workspace, pane)
      local ok = State.save_workspace_state(line, save_state)

      if ok then
        wezterm.log_info("ws: Saved workspace as '" .. line .. "'")

        local path_msg = save_state.cwd and (' at ' .. save_state.cwd) or ''

        UI.notify(
          window,
          'Workspace Saved',
          "Saved workspace '" .. line .. "'" .. path_msg
        )
        return
      end

      wezterm.log_warn("ws: Failed to save workspace '" .. line .. "'")
      UI.notify(
        window,
        'Workspace Save Failed',
        "Failed to save workspace as '" .. line .. "'."
      )
    end),
  }
end

---@return Action
function M.save_all_workspaces()
  return wezterm.action_callback(function(window, pane)
    local workspace_names = wezterm.mux.get_workspace_names()
    local active_workspace = wezterm.mux.get_active_workspace()

    table.sort(workspace_names)

    local timestamp = os.time()
    local workspace_states = {}

    for _, workspace_name in ipairs(workspace_names) do
      workspace_states[workspace_name] = build_save_state(
        workspace_name,
        workspace_name == active_workspace and pane or nil,
        timestamp
      )
    end

    local saved = #workspace_names

    if State.save_workspace_states(workspace_states) then
      wezterm.log_info('ws: Saved ' .. saved .. ' workspaces')
      UI.notify(
        window,
        'Workspaces Saved',
        'Saved ' .. saved .. ' workspaces successfully.'
      )
      return
    end

    local failed = workspace_names
    local summary = 'Saved '
      .. 0
      .. ' workspaces, failed for: '
      .. table.concat(failed, ', ')

    wezterm.log_warn('ws: ' .. summary)
    UI.notify(window, 'Workspace Save Completed With Errors', summary)
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
