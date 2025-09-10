# MCP CLI (Ruby)

Ruby-based MCP manager with CLI parity to dotfiles `bin/mcp`.

- Commands: install, update, integrate, disintegrate, uninstall, list, info,
  prompt, search; profiles (list/use/create).
- Sources: curated, mcp-get, Smithery; Node/Python install strategies.
- Clients: Claude, Codex, Goose. Idempotent config upserts.
  - Codex: uses `[mcp_servers.<name>]` in `~/.codex/config.toml`.

See dotfiles mcp/doc/TODO.md for the full concept and architecture.
