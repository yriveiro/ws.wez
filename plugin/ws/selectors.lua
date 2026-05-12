local wezterm = require 'wezterm' ---@type Wezterm
local act = wezterm.action

local Config = require 'ws.config'
local State = require 'ws.state'
local UI = require 'ws.ui'
local Utils = require 'ws.utils'
local Zoxide = require 'ws.zoxide'

local M = {}

---@param saved_workspaces WorkspacePickerSavedWorkspaceIndex
---@return string[]
local function get_sorted_saved_workspace_names(saved_workspaces)
  local names = {}

  for name in pairs(saved_workspaces) do
    table.insert(names, name)
  end

  table.sort(names)

  return names
end

---@param config WorkspacePickerResolvedConfig
---@return WorkspacePickerChoice[]
local function build_workspace_selector_choices(config)
  ---@type WorkspacePickerChoice[]
  local choices = {
    { id = 'save-all', label = 's  Save all workspaces' },
    { id = 'delete-saved-workspace', label = 'd  Delete saved workspace' },
    { id = 'create-workspace', label = 'c  Create new workspace' },
    { id = 'rename-workspace', label = 'e  Rename current workspace' },
  }

  local current = wezterm.mux.get_active_workspace()
  local workspace_choices = {}
  local default_workspace_choice

  for _, name in ipairs(wezterm.mux.get_workspace_names()) do
    local choice = {
      id = 'ws:' .. name,
      label = UI.format_live_workspace_label(name, name == current, config),
    }

    if name == 'default' then
      default_workspace_choice = choice
    else
      table.insert(workspace_choices, choice)
    end
  end

  if default_workspace_choice then
    table.insert(workspace_choices, 1, default_workspace_choice)
  end

  for _, choice in ipairs(workspace_choices) do
    table.insert(choices, choice)
  end

  local zoxide_dirs = Zoxide.get_directories()

  if #zoxide_dirs > 0 then
    table.insert(choices, {
      id = 'separator',
      label = UI.selector_separator(),
    })

    for _, directory in ipairs(zoxide_dirs) do
      table.insert(choices, {
        id = 'zoxide:' .. directory,
        label = UI.format_directory_label(directory, config),
      })
    end
  end

  return choices
end

---@param window Window
---@param pane Pane
---@param directory string
local function switch_to_directory_workspace(window, pane, directory)
  local expanded_directory = Utils.expand_home(directory, wezterm.home_dir)

  window:perform_action(
    act.SwitchToWorkspace {
      name = Utils.basename(expanded_directory),
      spawn = {
        cwd = expanded_directory,
      },
    },
    pane
  )
end

---@param window Window
---@param pane Pane
---@param opts {
---@  title: string,
---@  description: string,
---@  fuzzy_description: string,
---@  on_select: fun(window: Window, pane: Pane, saved_name: string, saved_state: WorkspacePickerSavedState|nil)
---@ }
local function show_saved_workspace_selector(window, pane, opts)
  local config = Config.get()
  local saved_workspaces = State.load_saved_workspaces()
  local saved_names = get_sorted_saved_workspace_names(saved_workspaces)

  if #saved_names == 0 then
    UI.notify_no_saved_workspaces(window)
    return
  end

  ---@type WorkspacePickerChoice[]
  local choices = {}

  for _, name in ipairs(saved_names) do
    table.insert(choices, {
      id = name,
      label = UI.format_saved_workspace_label(name, saved_workspaces[name], config),
    })
  end

  UI.show_input_selector(window, pane, {
    title = opts.title,
    choices = choices,
    description = opts.description,
    fuzzy_description = opts.fuzzy_description,
    on_select = function(win, current_pane, id)
      if not id then
        return
      end

      opts.on_select(win, current_pane, id, saved_workspaces[id])
    end,
  })
end

---@param window Window
---@param pane Pane
---@param callbacks {
---@  save_all_workspaces: fun(): Action,
---@  show_delete_menu: fun(window: Window, pane: Pane),
---@  create_workspace_manually: fun(): Action,
---@  rename_workspace: fun(): Action
---@ }
function M.show_workspace_selector(window, pane, callbacks)
  local config = Config.get()

  UI.show_input_selector(window, pane, {
    title = '(wezterm) Select workspace',
    choices = build_workspace_selector_choices(config),
    description = "(wezterm) Select workspace or directory: ['/': search]",
    fuzzy_description = '(wezterm) Select workspace or directory: ',
    on_select = function(win, current_pane, id)
      if not id or id == 'separator' then
        return
      end

      if id == 'save-all' then
        win:perform_action(callbacks.save_all_workspaces(), current_pane)
        return
      end

      if id == 'delete-saved-workspace' then
        callbacks.show_delete_menu(win, current_pane)
        return
      end

      if id == 'create-workspace' then
        win:perform_action(callbacks.create_workspace_manually(), current_pane)
        return
      end

      if id == 'rename-workspace' then
        win:perform_action(callbacks.rename_workspace(), current_pane)
        return
      end

      if id:sub(1, 3) == 'ws:' then
        win:perform_action(act.SwitchToWorkspace { name = id:sub(4) }, current_pane)
        return
      end

      if id:sub(1, 7) == 'zoxide:' then
        switch_to_directory_workspace(win, current_pane, id:sub(8))
      end
    end,
  })
end

---@param window Window
---@param pane Pane
function M.show_restore_menu(window, pane)
  show_saved_workspace_selector(window, pane, {
    title = '(wezterm) Restore workspace',
    description = '(wezterm) Restore a saved workspace: ',
    fuzzy_description = '(wezterm) Restore workspace: ',
    on_select = function(win, current_pane, saved_name, saved_state)
      if not saved_state then
        wezterm.log_warn("ws: Failed to load workspace state for '" .. saved_name .. "'")
        UI.notify(
          win,
          'Workspace Restore Failed',
          "Failed to load workspace state for '" .. saved_name .. "'."
        )
        return
      end

      local existing = State.get_restored_workspaces()
      local switch_args = {
        name = saved_name,
      }

      if
        not existing[saved_name]
        and type(saved_state.cwd) == 'string'
        and saved_state.cwd ~= ''
      then
        switch_args.spawn = {
          cwd = saved_state.cwd,
        }
      end

      win:perform_action(act.SwitchToWorkspace(switch_args), current_pane)

      wezterm.log_info("ws: Restored workspace '" .. saved_name .. "'")
      UI.notify(win, 'Workspace Restored', "Restored workspace '" .. saved_name .. "'.")
    end,
  })
end

---@param window Window
---@param pane Pane
function M.show_delete_menu(window, pane)
  show_saved_workspace_selector(window, pane, {
    title = '(wezterm) Delete saved workspace',
    description = '(wezterm) Delete a saved workspace: ',
    fuzzy_description = '(wezterm) Delete saved workspace: ',
    on_select = function(win, _, saved_name)
      if State.delete_workspace_state(saved_name) then
        wezterm.log_info("ws: Deleted saved workspace '" .. saved_name .. "'")
        UI.notify(
          win,
          'Workspace Deleted',
          "Deleted saved workspace '" .. saved_name .. "'."
        )
        return
      end

      wezterm.log_warn("ws: Failed to delete saved workspace '" .. saved_name .. "'")
      UI.notify(
        win,
        'Workspace Delete Failed',
        "Failed to delete saved workspace '" .. saved_name .. "'."
      )
    end,
  })
end

return M
