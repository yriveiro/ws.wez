local wezterm = require 'wezterm' ---@type Wezterm
local act = wezterm.action

local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local table_insert = table.insert
local table_sort = table.sort
local type = type

local home_dir = wezterm.home_dir
local mux = wezterm.mux
local mux_all_windows = wezterm.mux.all_windows

local Config = require 'ws.config'
local State = require 'ws.state'
local UI = require 'ws.ui'
local Utils = require 'ws.utils'
local Zoxide = require 'ws.zoxide'

local M = {}

local live_workspace_prefix = 'ws:'
local zoxide_choice_prefix = 'zoxide:'

---@param saved_workspaces WsWezSavedWorkspaceIndex
---@return string[]
local function get_sorted_saved_workspace_names(saved_workspaces)
  local names = {}

  for name in pairs(saved_workspaces) do
    table_insert(names, name)
  end

  table_sort(names)

  return names
end

---@return string[]
local function get_sorted_live_workspace_names()
  local names = mux.get_workspace_names()

  table_sort(names, function(left, right)
    if left == right then
      return false
    end

    if left == 'default' then
      return true
    end

    if right == 'default' then
      return false
    end

    return left < right
  end)

  return names
end

---@param value string
---@param prefix string
---@return string|nil
local function strip_prefix(value, prefix)
  if value:sub(1, #prefix) == prefix then
    return value:sub(#prefix + 1)
  end
end

---@param config WsWezResolvedConfig
---@return WsWezChoice[]
local function build_live_workspace_choices(config)
  local current = mux.get_active_workspace()
  local pane_counts = {}
  local workspace_choices = {}

  for _, mux_window in ipairs(mux_all_windows() or {}) do
    local ok_workspace, workspace_name = pcall(mux_window.get_workspace, mux_window)

    if ok_workspace and type(workspace_name) == 'string' and workspace_name ~= '' then
      pane_counts[workspace_name] = pane_counts[workspace_name] or 0

      local ok_tabs, tabs_with_info = pcall(mux_window.tabs_with_info, mux_window)

      if ok_tabs and type(tabs_with_info) == 'table' then
        for _, tab_info in ipairs(tabs_with_info) do
          if tab_info.tab then
            local ok_panes, panes_with_info =
              pcall(tab_info.tab.panes_with_info, tab_info.tab)

            if ok_panes and type(panes_with_info) == 'table' then
              pane_counts[workspace_name] = pane_counts[workspace_name] + #panes_with_info
            end
          end
        end
      end
    end
  end

  for _, name in ipairs(get_sorted_live_workspace_names()) do
    table_insert(workspace_choices, {
      id = live_workspace_prefix .. name,
      label = UI.format_live_workspace_label(
        name,
        name == current,
        pane_counts[name] or 0,
        config
      ),
    })
  end

  return workspace_choices
end

---@param config WsWezResolvedConfig
---@return WsWezChoice[]
local function build_workspace_selector_choices(config)
  local action_specs = {
    {
      id = 'save-current-workspace',
      text = 'Save current workspace state',
    },
    {
      id = 'save-all',
      text = 'Save all workspace states',
    },
    {
      id = 'restore-saved-workspace',
      text = 'Restore saved workspace state',
    },
    {
      id = 'delete-saved-workspace',
      text = 'Delete saved workspace state',
    },
    {
      id = 'create-workspace',
      text = 'Create live workspace',
    },
    {
      id = 'rename-workspace',
      text = 'Rename current live workspace',
    },
    {
      id = 'delete-workspace',
      text = 'Delete live workspace',
    },
  }

  table_sort(action_specs, function(left, right)
    return left.text < right.text
  end)

  ---@type WsWezChoice[]
  local choices = {}

  for _, spec in ipairs(action_specs) do
    table_insert(choices, {
      id = spec.id,
      label = UI.format_action_label(spec.text, config),
    })
  end

  for _, choice in ipairs(build_live_workspace_choices(config)) do
    table_insert(choices, choice)
  end

  local zoxide_dirs = Zoxide.get_directories()

  if #zoxide_dirs > 0 then
    table_insert(choices, {
      id = 'separator',
      label = UI.selector_separator(),
    })

    for _, directory in ipairs(zoxide_dirs) do
      table_insert(choices, {
        id = zoxide_choice_prefix .. directory,
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
  local expanded_directory = Utils.expand_home(directory, home_dir)

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
---@  on_select: fun(window: Window, pane: Pane, saved_name: string, saved_state: WsWezSavedState|nil)
---@ }
local function show_saved_workspace_selector(window, pane, opts)
  local config = Config.get()
  local saved_workspaces = State.load_saved_workspaces()
  local saved_names = get_sorted_saved_workspace_names(saved_workspaces)

  if #saved_names == 0 then
    UI.notify_no_saved_workspaces(window)
    return
  end

  ---@type WsWezChoice[]
  local choices = {}

  for _, name in ipairs(saved_names) do
    table_insert(choices, {
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
---@param opts {
---@  title: string,
---@  description: string,
---@  fuzzy_description: string,
---@  on_select: fun(window: Window, pane: Pane, workspace_name: string)
---@ }
local function show_live_workspace_selector(window, pane, opts)
  local config = Config.get()
  local choices = build_live_workspace_choices(config)

  if #choices == 0 then
    UI.notify_no_workspaces(window)
    return
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

      local workspace_name = strip_prefix(id, live_workspace_prefix)

      if not workspace_name then
        return
      end

      opts.on_select(win, current_pane, workspace_name)
    end,
  })
end

local selector_action_handlers = {
  ['save-current-workspace'] = function(window, pane, callbacks)
    window:perform_action(callbacks.save_current_workspace(), pane)
  end,
  ['save-all'] = function(window, pane, callbacks)
    window:perform_action(callbacks.save_all_workspaces(), pane)
  end,
  ['restore-saved-workspace'] = function(window, pane, callbacks)
    callbacks.show_restore_menu(window, pane)
  end,
  ['delete-workspace'] = function(window, pane, callbacks)
    callbacks.show_delete_live_menu(window, pane)
  end,
  ['delete-saved-workspace'] = function(window, pane, callbacks)
    callbacks.show_delete_saved_menu(window, pane)
  end,
  ['create-workspace'] = function(window, pane, callbacks)
    window:perform_action(callbacks.create_workspace_manually(), pane)
  end,
  ['rename-workspace'] = function(window, pane, callbacks)
    window:perform_action(callbacks.rename_workspace(), pane)
  end,
}

---@param workspace_name string
---@return string
local function get_delete_fallback_workspace_name(workspace_name)
  for _, name in ipairs(mux.get_workspace_names()) do
    if name ~= workspace_name then
      return name
    end
  end

  if workspace_name ~= 'default' then
    return 'default'
  end

  return 'workspace'
end

---@param workspace_name string
---@return boolean, string|nil
local function activate_workspace(workspace_name)
  for _, name in ipairs(mux.get_workspace_names()) do
    if name == workspace_name then
      local ok, err = pcall(mux.set_active_workspace, workspace_name)

      return ok, err
    end
  end

  local spawned, spawn_err = pcall(mux.spawn_window, {
    workspace = workspace_name,
  })

  if not spawned then
    return false, spawn_err
  end

  local ok, err = pcall(mux.set_active_workspace, workspace_name)

  return ok, err
end

---@param window Window
---@param pane Pane
---@param callbacks {
---@  save_current_workspace: fun(): Action,
---@  save_all_workspaces: fun(): Action,
---@  show_restore_menu: fun(window: Window, pane: Pane),
---@  show_delete_live_menu: fun(window: Window, pane: Pane),
---@  show_delete_saved_menu: fun(window: Window, pane: Pane),
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

      local action = selector_action_handlers[id]

      if action then
        action(win, current_pane, callbacks)
        return
      end

      local workspace_name = strip_prefix(id, live_workspace_prefix)

      if workspace_name then
        win:perform_action(act.SwitchToWorkspace { name = workspace_name }, current_pane)
        return
      end

      local directory = strip_prefix(id, zoxide_choice_prefix)

      if directory then
        switch_to_directory_workspace(win, current_pane, directory)
      end
    end,
  })
end

---@param window Window
---@param pane Pane
function M.show_restore_menu(window, pane)
  show_saved_workspace_selector(window, pane, {
    title = '(wezterm) Restore saved workspace state',
    description = '(wezterm) Restore a saved workspace state: ',
    fuzzy_description = '(wezterm) Restore saved workspace state: ',
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
function M.show_delete_live_menu(window, pane)
  show_live_workspace_selector(window, pane, {
    title = '(wezterm) Delete live workspace',
    description = '(wezterm) Delete a live workspace: ',
    fuzzy_description = '(wezterm) Delete live workspace: ',
    on_select = function(win, current_pane, workspace_name)
      local deleting_active_workspace = workspace_name == mux.get_active_workspace()
      local deleted, result = State.delete_live_workspace(workspace_name, {
        current_pane_id = current_pane:pane_id(),
        defer_current_pane = deleting_active_workspace,
      })

      if not deleted then
        local detail = type(result) == 'string' and result or 'unknown error'

        wezterm.log_warn(
          "ws: Failed to delete live workspace '" .. workspace_name .. "': " .. detail
        )
        UI.notify(
          win,
          'Workspace Delete Failed',
          "Failed to delete live workspace '" .. workspace_name .. "'."
        )
        return
      end

      if
        deleting_active_workspace
        and type(result) == 'table'
        and result.deferred_pane_id
      then
        local fallback_workspace = get_delete_fallback_workspace_name(workspace_name)
        local activated, activate_err = activate_workspace(fallback_workspace)

        if not activated then
          wezterm.log_warn(
            "ws: Failed to switch away from workspace '"
              .. workspace_name
              .. "': "
              .. tostring(activate_err)
          )
          UI.notify(
            win,
            'Workspace Delete Failed',
            "Failed to finish deleting live workspace '" .. workspace_name .. "'."
          )
          return
        end

        State.kill_pane_later(result.deferred_pane_id)
      end

      wezterm.log_info("ws: Deleted live workspace '" .. workspace_name .. "'")
      UI.notify(
        win,
        'Workspace Deleted',
        "Deleted live workspace '" .. workspace_name .. "'."
      )
    end,
  })
end

---@param window Window
---@param pane Pane
function M.show_delete_saved_menu(window, pane)
  show_saved_workspace_selector(window, pane, {
    title = '(wezterm) Delete saved workspace state',
    description = '(wezterm) Delete a saved workspace state: ',
    fuzzy_description = '(wezterm) Delete saved workspace state: ',
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

---@param window Window
---@param pane Pane
function M.show_delete_menu(window, pane)
  M.show_delete_live_menu(window, pane)
end

return M
