# ws.wez
- Purpose: WezTerm plugin for workspace management with picker UI, zoxide integration, saved workspace state persistence, restore/delete actions, and optional startup restore.
- Stack: Lua 5.4, WezTerm plugin/runtime APIs, StyLua for formatting.
- Structure: public entrypoint in `plugin/init.lua`; implementation under `plugin/ws/*.lua`; docs in `README.md` and `docs/configuration.md`; examples in `examples/*.lua`.
- Public surface centers on `apply_to_config`, selector actions, save/restore workspace state helpers, and config setup.