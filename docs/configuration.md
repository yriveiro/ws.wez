# Configuration Appendix

Compact reference for `ws.wez` options and public API. See [`README.md`](../README.md) for the quick-start flow.

## Setup

Use either form:

```lua
local wezterm = require 'wezterm' ---@type Wezterm
local ws = wezterm.plugin.require 'https://github.com/yriveiro/ws.wez'
local config = wezterm.config_builder() ---@type Config

ws.setup(opts)
ws.apply_to_config(config)
```

```lua
local wezterm = require 'wezterm' ---@type Wezterm
local ws = wezterm.plugin.require 'https://github.com/yriveiro/ws.wez'
local config = wezterm.config_builder() ---@type Config

ws.apply_to_config(config, opts)
```

## Options

| Option | Type | Default |
| --- | --- | --- |
| `zoxide_path` | `string` | `'/opt/homebrew/bin/zoxide'` |
| `colors` | `table` | see below |
| `labels` | `table` | see below |
| `style` | `table` | see below |
| `activate_keytable` | `table \| false` | `{ mods = 'LEADER', key = 'w' }` |
| `restore_on_gui_startup` | `boolean` | `true` |

### `zoxide_path`

Path to the `zoxide` executable used for directory-backed workspace creation.

### `colors`

Controls selector colors.

```lua
colors = {
  action_prefix = '#7dcfff',
  workspace_prefix = '#9ece6a',
  zoxide_prefix = '#f7768e',
  current_indicator = '#9ece6a',
  pane_count = '#ff9e64',
  text = '#c8d0e0',
  path = '#565f89',
  separator = '#6c7086',
}
```

- `action_prefix`: action entry icon color
- `workspace_prefix`: live workspace label color
- `zoxide_prefix`: zoxide entry label color
- `current_indicator`: active workspace marker color
- `pane_count`: live pane count color
- `text`: main item text color
- `path`: zoxide path color
- `separator`: section separator color

### `labels`

Controls optional selector text shown next to icons.

```lua
labels = {
  workspace = '',
  zoxide = '',
  current = '',
}
```

- `workspace`: optional text after the live workspace icon
- `zoxide`: optional text after the zoxide icon
- `current`: optional text after the active workspace marker icon

### `style`

Controls selector icons. Values can be either Nerd Font symbol names from `wezterm.nerdfonts` or literal strings.

```lua
style = {
  action = 'seti_config',
  current = 'cod_rocket',
  pane_count = 'cod_library',
  workspace = 'md_television_guide',
  zoxide = 'oct_file_directory_fill',
}
```

- `action`: icon for selector action entries
- `current`: marker icon for the active live workspace
- `pane_count`: icon shown with the live pane count
- `workspace`: icon for live workspace entries
- `zoxide`: icon for zoxide directory entries

### `activate_keytable`

Controls the default keybinding that opens the workspace selector.

```lua
activate_keytable = { mods = 'LEADER', key = 'w' }
```

Set it to `false` to disable the automatic opener and bind actions yourself.

### `restore_on_gui_startup`

Restores saved workspace states during `gui-startup`. Restore runs once per GUI startup, skips workspaces that are already live, and reuses the saved `cwd` when recreating a workspace.

## Public API

The supported integration surface is the plugin facade returned by:

```lua
local ws = wezterm.plugin.require 'https://github.com/yriveiro/ws.wez'
```

Direct imports of internal runtime modules are not part of the supported API.
The public facade stays at `plugin/init.lua`, while the implementation lives under `plugin/ws/*` and is loaded by extending `package.path` from `wezterm.plugin.list()`.

### `setup(opts)`

Set the active plugin configuration and register startup restore when enabled. Returns the plugin module.

### `apply_to_config(config, opts)`

Apply plugin configuration to a WezTerm config and add the default selector keybinding unless `activate_keytable = false`. Returns the modified `config`.

### `show_workspace_selector(window, pane)`

Open the main workspace selector. The selector includes two separate groups of actions:

- live workspace actions: switch, create, rename, delete
- saved workspace state actions: save current, save all, restore, delete saved

### `save_workspace()`

Compatibility alias for `save_workspace_as()`.

### `save_workspace_as()`

Return a WezTerm action that prompts for a saved state name and saves the active live workspace under that name. If the saved entry already exists, it is updated in place. Saves fail when the current `cwd` cannot be captured.

### `save_current_workspace()`

Return a WezTerm action that saves the active live workspace under its current name. Existing saved entries with the same name are updated in place. Saves fail when the current `cwd` cannot be captured.

### `save_all_workspaces()`

Return a WezTerm action that saves workspace state for all live workspaces. Existing saved entries with the same names are updated in place. Workspaces whose `cwd` cannot be captured are skipped.

### `show_restore_menu(window, pane)`

Open the saved-workspace-state restore menu.

### `show_delete_menu(window, pane)`

Compatibility alias for `show_delete_live_menu(window, pane)`.

### `show_delete_live_menu(window, pane)`

Open the live-workspace delete menu. This closes the selected live WezTerm workspace only.

### `show_delete_saved_menu(window, pane)`

Open the saved-workspace-state delete menu. This removes saved entries only and does not close live WezTerm workspaces.

### `restore_all_workspaces()`

Return a WezTerm action that restores all saved workspace states immediately.

### `restore_workspaces_on_gui_startup(cmd)`

Restore saved workspace states from the `gui-startup` event. This is usually registered automatically when `restore_on_gui_startup = true`.

### `get_data_dir()`

Return the directory used for saved workspace state data.

### `rename_workspace()`

Return a WezTerm action that renames the current workspace.

### `create_workspace_manually()`

Return a WezTerm action that prompts for and creates a workspace manually.

## Compatibility Notes

- The public facade above is the supported integration path.
- Internal namespaced modules under `plugin/ws/*` are implementation details and may change without notice.

## Type Support

With `wezterm-types`, annotate WezTerm values like this:

```lua
local wezterm = require 'wezterm' ---@type Wezterm
local config = wezterm.config_builder() ---@type Config
local ws = wezterm.plugin.require 'https://github.com/yriveiro/ws.wez'
```

`wezterm-types` provides the core WezTerm API types. This repository declares its own plugin facade type as `WsWezPlugin` in `plugin/ws/types.lua`, so it is available while editing this repo or if you add this plugin checkout to LuaLS `workspace.library`.
