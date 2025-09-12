# MCP CLI (Ruby)

Ruby-based MCP manager with CLI parity to dotfiles `bin/mcp`.

- Commands: install, update, integrate, disintegrate, uninstall, list, info,
  prompt, search; profiles (list/use/create).
- Sources: curated, mcp-get, Smithery; Node/Python install strategies.
- Clients: Claude, Codex, Goose. Idempotent config upserts.
  - Codex: uses `[mcp_servers.<name>]` in `~/.codex/config.toml`.

See dotfiles mcp/doc/TODO.md for the full concept and architecture.

## Debugging Goose + MCPs

- Logs: tail `~/.config/Goose/logs/main.log` while reproducing.
  - Example: `tail -f ~/.config/Goose/logs/main.log | rg -n "appsignal|APPSIGNAL|rmcp|tools|ERROR"`
- Handshake: look for `rmcp::service` lines (protocol, capabilities, server name) to confirm the MCP is connected.
- Tool calls: search for `tool_router_index_manager` and errors during tool execution.
- Common causes of loops/hangs:
  - Missing env in GUI: `Failed to fetch secret from config., key: USER_AGENT, ext_name: appsignal`.
    - Fix: run `mcp integrate appsignal` (adds defaults for USER_AGENT, enables APPSIGNAL_DEBUG) and restart Goose.
  - Container buffering: ensure `docker run -i --rm` (no `-t`).
  - Timeouts: set `extensions.<name>.timeout: 120` when needed.
- Increase verbosity:
  - AppSignal MCP: set `APPSIGNAL_DEBUG=true` (our Goose integration enables by default; toggle under `extensions.appsignal.envs`).
  - Goose/rmcp trace: launch from a terminal with `RUST_LOG=rmcp=trace,goosed=debug,goose=debug goose-desktop` and reproduce.

## MCP Inspector

Exercise an MCP server outside Goose/Claude to isolate issues.

- One-off run (no install):
  - `npx @modelcontextprotocol/inspector --command docker --args "run -i --rm -e APPSIGNAL_API_KEY -e USER_AGENT -e APPSIGNAL_DEBUG=true appsignal/mcp"`
- Verify:
  - `tools/list` returns expected tools (e.g., 14 for AppSignal).
  - Simple tool invocation returns quickly with JSON or a clear error.

Tip: Use the official image `appsignal/mcp`; no local tag is required.
