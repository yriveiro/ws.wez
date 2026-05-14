# ws.wez

Compact workspace picker for [WezTerm](https://wezfurlong.org/wezterm/index.html) with [zoxide](https://github.com/ajeetdsouza/zoxide) integration and saved workspace restore.

- Configuration appendix: [`docs/configuration.md`](docs/configuration.md)
- Examples: [`examples/basic.lua`](examples/basic.lua), [`examples/custom.lua`](examples/custom.lua), [`examples/manual-keybindings.lua`](examples/manual-keybindings.lua)

## Install

```lua
local wezterm = require 'wezterm' ---@type Wezterm
local ws = wezterm.plugin.require 'https://github.com/yriveiro/ws.wez'

local config = wezterm.config_builder() ---@type Config

config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }

ws.apply_to_config(config)

return config
```

## Configure

`apply_to_config(config, opts)` is the main entrypoint. Pass options there to keep the plugin setup in one place.

```lua
local wezterm = require 'wezterm' ---@type Wezterm
local ws = wezterm.plugin.require 'https://github.com/yriveiro/ws.wez'

local config = wezterm.config_builder() ---@type Config

config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }

ws.apply_to_config(config, {
  zoxide_path = '/opt/homebrew/bin/zoxide',
  restore_on_gui_startup = true,
  activate_keytable = { mods = 'LEADER', key = 'w' },
  colors = {
    action_prefix = '#7dcfff',
    workspace_prefix = '#a6e3a1',
    zoxide_prefix = '#f38ba8',
    current_indicator = '#a6e3a1',
    text = '#cdd6f4',
    path = '#6c7086',
  },
  labels = {
    workspace = '',
    zoxide = '',
    current = '',
  },
  style = {
    action = 'seti_config',
    current = 'pl_right_hard_divider',
    pane_count = 'cod_library',
    workspace = 'md_television_guide',
    zoxide = 'oct_file_directory_fill',
  },
})

return config
```

`setup(opts)` is also supported when you want to configure the plugin first and call `apply_to_config(config)` later.

## Usage

- `LEADER` + `w`: open the workspace selector
- Live workspaces: switch, create, rename, and delete live mux workspaces
- Live workspace entries show the current workspace marker and live pane counts
- Saved workspace states: save current, save all, restore saved, and delete saved state entries
- `s`: save the current workspace state from the selector
- `a`: save all live workspace states from the selector
- `o`: restore a saved workspace state
- `x`: delete a saved workspace state
- `d`: delete a live workspace
- `c`: create a workspace manually
- `e`: rename the current workspace
- `/`: start fuzzy search in the selector
- Startup restore runs once during `gui-startup`
- Startup restore skips workspaces that are already live
- Restored workspaces reuse the saved `cwd` when available

## Supported Surface

Use the plugin through the public facade returned by:

```lua
local ws = wezterm.plugin.require 'https://github.com/yriveiro/ws.wez'
```

Supported entrypoints are:

- `ws.setup(...)`
- `ws.apply_to_config(...)`
- `ws.show_workspace_selector(...)`
- `ws.save_current_workspace()`
- `ws.save_workspace_as()`
- `ws.save_all_workspaces()`
- `ws.show_restore_menu(...)`
- `ws.show_delete_live_menu(...)`
- `ws.show_delete_menu(...)`
- `ws.show_delete_saved_menu(...)`
- `ws.restore_all_workspaces()`
- `ws.restore_workspaces_on_gui_startup(...)`
- `ws.get_data_dir()`
- `ws.rename_workspace()`
- `ws.create_workspace_manually()`
- Compatibility aliases: `ws.save_workspace()`, `ws.show_delete_menu(...)`

Direct imports of internal runtime modules under `plugin/ws/*.lua` are not part of the supported public API.

## Runtime Layout

WezTerm plugins are loaded through a flat entrypoint at `plugin/init.lua`.
This plugin keeps that public entrypoint, then extends `package.path` from `wezterm.plugin.list()` so the implementation can live under the namespaced `plugin/ws/*` tree.

That mirrors the multi-file plugin-loading pattern used by [`wezterm-status`](https://github.com/yriveiro/wezterm-status) while avoiding generic internal module names like `config` or `utils` in the shared Lua `require` space.

> [!NOTE]
> The default opener uses `LEADER`, so set `config.leader` in your WezTerm config.
> See the [leader key docs](https://wezfurlong.org/wezterm/config/keys.html#leader-key).

## Options

- `zoxide_path`: path to the `zoxide` executable
- `colors`: selector colors
- `labels`: optional selector text shown next to icons
- `style`: selector icon names or literal glyphs
- `activate_keytable`: default opener binding, or `false` to disable it
- `restore_on_gui_startup`: restore saved workspaces during `gui-startup`

See [`docs/configuration.md`](docs/configuration.md) for defaults, field-level reference, and the full public API.

## Compatibility

- `ws.save_workspace()` is kept as an alias for `ws.save_workspace_as()`
- `ws.show_delete_menu(...)` is kept as an alias for `ws.show_delete_live_menu(...)`

## Type Annotations

With [wezterm-types](https://github.com/DrKJeff16/wezterm-types), annotate the built-in WezTerm values in your config:

```lua
local wezterm = require 'wezterm' ---@type Wezterm
local config = wezterm.config_builder() ---@type Config
local ws = wezterm.plugin.require 'https://github.com/yriveiro/ws.wez'
```

`wezterm-types` currently provides WezTerm API annotations like `Wezterm`, `Config`, `Window`, and `Pane`; it does not currently ship a `ws.wez` plugin facade annotation.

This repository declares its own plugin facade type as `WsWezPlugin` in `plugin/ws/types.lua`, so it is available while editing this repo or if you add this plugin checkout to your LuaLS `workspace.library`.

## License

MIT License.
