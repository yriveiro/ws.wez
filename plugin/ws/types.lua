---@class WsWezColors
---@field action_prefix? string
---@field current_indicator? string
---@field path? string
---@field text? string
---@field workspace_prefix? string
---@field zoxide_prefix? string

---@class (exact) WsWezResolvedColors
---@field action_prefix string
---@field current_indicator string
---@field path string
---@field text string
---@field workspace_prefix string
---@field zoxide_prefix string

---@class WsWezStyle
---@field action? string
---@field current? string
---@field pane_count? string
---@field workspace? string
---@field zoxide? string

---@class (exact) WsWezResolvedStyle
---@field action string
---@field current string
---@field pane_count string
---@field workspace string
---@field zoxide string

---@class WsWezLabels
---@field current? string
---@field workspace? string
---@field zoxide? string

---@class (exact) WsWezResolvedLabels
---@field current string
---@field workspace string
---@field zoxide string

---@class WsWezKeybind
---@field key string
---@field mods string

---@class WsWezConfig
---@field activate_keytable? WsWezKeybind|false
---@field colors? WsWezColors
---@field labels? WsWezLabels
---@field restore_on_gui_startup? boolean
---@field style? WsWezStyle
---@field zoxide_path? string

---@class (exact) WsWezResolvedConfig
---@field activate_keytable WsWezKeybind|false
---@field colors WsWezResolvedColors
---@field labels WsWezResolvedLabels
---@field restore_on_gui_startup boolean
---@field style WsWezResolvedStyle
---@field zoxide_path string

---@class WsWezChoice
---@field id string
---@field label string

---@class WsWezSavedState
---@field cwd? string
---@field timestamp? integer

---@alias WsWezSavedWorkspaceIndex table<string, WsWezSavedState>

---@class WsWezRestoreResult
---@field failed string[]
---@field first_restored_workspace string|nil
---@field found integer
---@field restored integer
---@field skipped integer

---@class WsWezRestoreOptions
---@field cmd? SpawnCommand

---@class WsWezSpawnWindowArgs: SpawnCommand
---@field height? integer
---@field width? integer
---@field workspace string

---@class WsWezGlobalState
---@field restore_attempted_on_gui_startup? boolean

---@class WsWezInputSelectorOpts
---@field choices WsWezChoice[]
---@field description string
---@field fuzzy_description string
---@field on_select CallbackInputSelector
---@field title string

---@class WsWezPlugin
---@field apply_to_config fun(config: Config, opts?: WsWezConfig): Config
---@field create_workspace_manually fun(): Action
---@field get_data_dir fun(): string
---@field rename_workspace fun(): Action
---@field restore_all_workspaces fun(): Action
---@field restore_workspaces_on_gui_startup fun(cmd?: SpawnCommand)
---@field save_all_workspaces fun(): Action
---@field save_current_workspace fun(): Action
---@field save_workspace_as fun(): Action
---@field save_workspace fun(): Action
---@field setup fun(opts?: WsWezConfig): WsWezPlugin
---@field show_delete_live_menu fun(window: Window, pane: Pane)
---@field show_delete_menu fun(window: Window, pane: Pane)
---@field show_delete_saved_menu fun(window: Window, pane: Pane)
---@field show_restore_menu fun(window: Window, pane: Pane)
---@field show_workspace_selector fun(window: Window, pane: Pane)

return {}
