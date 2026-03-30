# TOOLS.md — Cipher (CTO) Dev Environment

## VS Code
- Installed: /Applications/Visual Studio Code.app
- CLI: `code` (available in PATH)
- Extensions: Claude Code, Prettier, ESLint, Python, Azure Pack

## Claude Code
- Installed: /opt/homebrew/bin/claude
- Version: 2.1.58
- Usage: run `claude` in any project directory to start a coding session

## Launching a project
```bash
code /path/to/project       # Open in VS Code
cd /path/to/project && claude  # Start Claude Code session
```

## Cipher's workspace
/Users/apex/.openclaw/workspace-cto

## Notes
- Always open projects via `code <path>` for full IDE support
- Use `claude` for autonomous coding tasks within a project directory
