# Style and Conventions
- Lua code uses 2-space indentation, single quotes preferred, and sorted `require` blocks per `stylua.toml`.
- Keep changes minimal and local; internal modules live under `plugin/ws/*`.
- Type annotations are provided with EmmyLua/LuaLS style comments (for WezTerm and plugin facade types).
- Public API is documented in `README.md` and `docs/configuration.md`; avoid direct internal-module API commitments.