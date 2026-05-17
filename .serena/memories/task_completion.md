# Task Completion
- Format touched Lua files with `stylua`.
- Run `luac -p` on touched files at minimum; for plugin changes, prefer checking all `plugin/init.lua` and `plugin/ws/*.lua`.
- Review `git diff` to confirm the change stayed minimal and targeted.
- If behavior depends on WezTerm runtime, note any runtime/manual verification still needed.