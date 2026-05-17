# Suggested Commands
- Format a file: `stylua "plugin/ws/selectors.lua"`
- Format repo: `stylua "plugin/**/*.lua" "examples/**/*.lua"`
- Syntax check one file: `luac -p "plugin/ws/selectors.lua"`
- Syntax check plugin files: `for f in plugin/init.lua plugin/ws/*.lua; do luac -p "$f" || exit 1; done`
- Inspect status: `git status --short`
- Review diff: `git diff -- plugin/ws/selectors.lua`