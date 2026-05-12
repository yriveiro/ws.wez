# Configuration Appendix

Compact reference for `ws.wez` options and public API. See [`README.md`](../README.md) for the quick-start flow.

## Setup

Use either form:

```lua
local ws = wezterm.plugin.require 'https://github.com/yriveiro/ws.wez'

ws.setup(opts)
ws.apply_to_config(config)
```

```lua
local ws = wezterm.plugin.require 'https://github.com/yriveiro/ws.wez'

ws.apply_to_config(config, opts)
```

## Options

| Option | Type | Default |
| --- | --- | --- |
| `zoxide_path` | `string` | `'/opt/homebrew/bin/zoxide'` |
| `colors` | `table` | see below |
| `labels` | `table` | see below |
| `activate_keytable` | `table \| false` | `{ mods = 'LEADER', key = 'w' }` |
| `restore_on_gui_startup` | `boolean` | `true` |

### `zoxide_path`

Path to the `zoxide` executable used for directory-backed workspace creation.

### `colors`

Controls selector colors.

```lua
colors = {
  workspace_prefix = '#9ece6a',
  zoxide_prefix = '#f7768e',
  current_indicator = '#9ece6a',
  text = '#c8d0e0',
  path = '#565f89',
}
```

- `workspace_prefix`: live workspace label color
- `zoxide_prefix`: zoxide entry label color
- `current_indicator`: active workspace marker color
- `text`: main item text color
- `path`: zoxide path color

### `labels`

Controls selector labels.

```lua
labels = {
  workspace = '[Workspace]',
  zoxide = '[Zoxide]',
  current = '<- current',
}
```

- `workspace`: label for live workspace entries
- `zoxide`: label for zoxide entries
- `current`: marker for the active workspace

### `activate_keytable`

Controls the default keybinding that opens the workspace selector.

```lua
activate_keytable = { mods = 'LEADER', key = 'w' }
```

Set it to `false` to disable the automatic opener and bind actions yourself.

### `restore_on_gui_startup`

Restores saved workspaces during `gui-startup`. Restore runs once per GUI startup, skips workspaces that are already live, and reuses the saved `cwd` when recreating a workspace.

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

Open the main workspace selector.

### `save_workspace()`

Return a WezTerm action that saves the current workspace.

### `save_all_workspaces()`

Return a WezTerm action that saves all live workspaces.

### `show_restore_menu(window, pane)`

Open the saved-workspace restore menu.

### `show_delete_menu(window, pane)`

Open the saved-workspace delete menu. This removes saved entries only and does not close live WezTerm workspaces.

### `restore_all_workspaces()`

Return a WezTerm action that restores all saved workspaces immediately.

### `restore_workspaces_on_gui_startup(cmd)`

Restore saved workspaces from the `gui-startup` event. This is usually registered automatically when `restore_on_gui_startup = true`.

### `get_data_dir()`

Return the directory used for saved workspace data.

### `rename_workspace()`

Return a WezTerm action that renames the current workspace.

### `create_workspace_manually()`

Return a WezTerm action that prompts for and creates a workspace manually.

## Compatibility Notes

- The public facade above is the supported integration path.
- Internal namespaced modules under `plugin/ws/*` are implementation details and may change without notice.
