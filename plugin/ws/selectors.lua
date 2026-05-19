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
local section_choice_prefix = 'section:'
local zoxide_choice_prefix = 'zoxide:'

---@param choices WsWezChoice[]
---@param id_suffix string
---@param title string
---@param width integer
local function append_section_separator(choices, id_suffix, title, width)
  table_insert(choices, {
    id = section_choice_prefix .. id_suffix,
    label = UI.selector_separator(title, width),
  })
end

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

---@param current_width integer
---@param text string|nil
---@return integer
local function update_max_width(current_width, text)
  local width = UI.display_width(text)

  if width > current_width then
    return width
  end

  return current_width
end

---@param widths integer[]
---@return integer
local function combine_segment_widths(widths)
  local segment_count = 0
  local total_width = 0

  for _, width in ipairs(widths) do
    if type(width) == 'number' and width > 0 then
      segment_count = segment_count + 1
      total_width = total_width + width
    end
  end

  if segment_count > 1 then
    total_width = total_width + segment_count - 1
  end

  return total_width
end

---@return { is_current: boolean, name: string, pane_count: integer }[]
local function collect_live_workspace_entries()
  local current = mux.get_active_workspace()
  local pane_counts = {}
  local live_entries = {}

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
    table_insert(live_entries, {
      is_current = name == current,
      name = name,
      pane_count = pane_counts[name] or 0,
    })
  end

  return live_entries
end

---@param config WsWezResolvedConfig
---@param live_entries { is_current: boolean, name: string, pane_count: integer }[]
---@param layout { current_width?: integer, name_width?: integer, pane_count_width?: integer, prefix_width?: integer }|nil
---@return WsWezChoice[]
local function build_live_workspace_choices(config, live_entries, layout)
  local workspace_choices = {}

  for _, entry in ipairs(live_entries) do
    table_insert(workspace_choices, {
      id = live_workspace_prefix .. entry.name,
      label = UI.format_live_workspace_label(
        entry.name,
        entry.is_current,
        entry.pane_count,
        config,
        layout
      ),
    })
  end

  return workspace_choices
end

---@param config WsWezResolvedConfig
---@param action_specs { id: string, text: string }[]
---@param live_entries { is_current: boolean, name: string, pane_count: integer }[]
---@param zoxide_dirs string[]
---@return {
---@  action: { prefix_width: integer, text_width: integer },
---@  separator_width: integer,
---@  workspace: { current_width: integer, name_width: integer, pane_count_width: integer, prefix_width: integer },
---@  zoxide: { name_width: integer, prefix_width: integer },
---@}
local function build_workspace_selector_layout(config, action_specs, live_entries, zoxide_dirs)
  local action_text_width = 0
  local current_width = UI.display_width(UI.current_indicator_text(config))
  local destination_name_width = 0
  local max_row_width = 0
  local pane_count_width = 0
  local prefix_width = 0

  prefix_width = update_max_width(prefix_width, UI.action_prefix_text(config))
  prefix_width = update_max_width(prefix_width, UI.live_workspace_prefix_text(config))
  prefix_width = update_max_width(prefix_width, UI.zoxide_prefix_text(config))

  for _, spec in ipairs(action_specs) do
    action_text_width = update_max_width(action_text_width, spec.text)
  end

  for _, entry in ipairs(live_entries) do
    destination_name_width = update_max_width(destination_name_width, entry.name)
    pane_count_width = update_max_width(
      pane_count_width,
      UI.live_workspace_pane_count_text(entry.pane_count, config)
    )
  end

  for _, directory in ipairs(zoxide_dirs) do
    destination_name_width = update_max_width(destination_name_width, Utils.basename(directory))
  end

  max_row_width = combine_segment_widths {
    prefix_width,
    action_text_width,
  }
  max_row_width = update_max_width(
    max_row_width,
    string.rep(
      ' ',
      combine_segment_widths {
        prefix_width,
        destination_name_width,
        pane_count_width,
        current_width,
      }
    )
  )

  for _, directory in ipairs(zoxide_dirs) do
    local zoxide_row_width = combine_segment_widths {
      prefix_width,
      destination_name_width,
      UI.display_width('(' .. directory .. ')'),
    }

    if zoxide_row_width > max_row_width then
      max_row_width = zoxide_row_width
    end
  end

  return {
    action = {
      prefix_width = prefix_width,
      text_width = action_text_width,
    },
    separator_width = max_row_width,
    workspace = {
      current_width = current_width,
      name_width = destination_name_width,
      pane_count_width = pane_count_width,
      prefix_width = prefix_width,
    },
    zoxide = {
      name_width = destination_name_width,
      prefix_width = prefix_width,
    },
  }
end

---@param config WsWezResolvedConfig
---@param live_entries { is_current: boolean, name: string, pane_count: integer }[]
---@return { current_width: integer, name_width: integer, pane_count_width: integer, prefix_width: integer }
local function build_live_workspace_layout(config, live_entries)
  local name_width = 0
  local pane_count_width = 0

  for _, entry in ipairs(live_entries) do
    name_width = update_max_width(name_width, entry.name)
    pane_count_width = update_max_width(
      pane_count_width,
      UI.live_workspace_pane_count_text(entry.pane_count, config)
    )
  end

  return {
    current_width = UI.display_width(UI.current_indicator_text(config)),
    name_width = name_width,
    pane_count_width = pane_count_width,
    prefix_width = UI.display_width(UI.live_workspace_prefix_text(config)),
  }
end

---@param saved_names string[]
---@return { name_width: integer }
local function build_saved_workspace_layout(saved_names)
  local name_width = 0

  for _, name in ipairs(saved_names) do
    name_width = update_max_width(name_width, name)
  end

  return {
    name_width = name_width,
  }
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
  local live_entries = collect_live_workspace_entries()
  local zoxide_dirs = Zoxide.get_directories()
  local layout = build_workspace_selector_layout(config, action_specs, live_entries, zoxide_dirs)
  local live_workspace_choices = build_live_workspace_choices(
    config,
    live_entries,
    layout.workspace
  )

  append_section_separator(choices, 'options', 'options', layout.separator_width)

  for _, spec in ipairs(action_specs) do
    table_insert(choices, {
      id = spec.id,
      label = UI.format_action_label(spec.text, config, layout.action),
    })
  end

  if #live_workspace_choices > 0 then
    append_section_separator(choices, 'workspaces', 'workspaces', layout.separator_width)

    for _, choice in ipairs(live_workspace_choices) do
      table_insert(choices, choice)
    end
  end

  if #zoxide_dirs > 0 then
    append_section_separator(choices, 'zoxide-entries', 'zoxide entries', layout.separator_width)

    for _, directory in ipairs(zoxide_dirs) do
      table_insert(choices, {
        id = zoxide_choice_prefix .. directory,
        label = UI.format_directory_label(directory, config, layout.zoxide),
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
  local layout = build_saved_workspace_layout(saved_names)

  if #saved_names == 0 then
    UI.notify_no_saved_workspaces(window)
    return
  end

  ---@type WsWezChoice[]
  local choices = {}

  for _, name in ipairs(saved_names) do
    table_insert(choices, {
      id = name,
      label = UI.format_saved_workspace_label(name, saved_workspaces[name], config, layout),
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
  local live_entries = collect_live_workspace_entries()
  local layout = build_live_workspace_layout(config, live_entries)
  local choices = build_live_workspace_choices(config, live_entries, layout)

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
---@param cwd string|nil
---@return boolean, string|nil
local function activate_workspace(workspace_name, cwd)
  for _, name in ipairs(mux.get_workspace_names()) do
    if name == workspace_name then
      local ok, err = pcall(mux.set_active_workspace, workspace_name)

      return ok, err
    end
  end

  local spawn_args = {
    workspace = workspace_name,
  }

  if type(cwd) == 'string' and cwd ~= '' then
    spawn_args.cwd = cwd
  end

  local spawned, spawn_err = pcall(mux.spawn_window, spawn_args)

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
      if not id or strip_prefix(id, section_choice_prefix) then
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

      if existing[saved_name] then
        win:perform_action(act.SwitchToWorkspace { name = saved_name }, current_pane)
      else
        local activated, activate_err = activate_workspace(saved_name, saved_state.cwd)

        if not activated then
          wezterm.log_warn(
            "ws: Failed to restore workspace '"
              .. saved_name
              .. "': "
              .. tostring(activate_err)
          )
          UI.notify(
            win,
            'Workspace Restore Failed',
            "Failed to restore workspace '" .. saved_name .. "'."
          )
          return
        end
      end

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
