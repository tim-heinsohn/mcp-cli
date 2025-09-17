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

## AppSignal API Key Helpers

The Codex integration ships with `~/mcp/bin/appsignal-mcp-wrapper`, which

1. Loads `~/mcp/.env` (copy `~/mcp/.env.sample`) to pick up per-user settings.
2. Accepts an `APPSIGNAL_API_KEY` if Codex forwards one untouched.
3. Otherwise runs `APPSIGNAL_API_KEY_HELPER` (defaults to
   `~/ia.dotfiles/bin/appsignal_api_key_helper`). The helper just needs to print the key on
   stdout, so you can wrap gopass, 1Password, credentials from your password
   manager, etc.

Every step is logged to `~/.codex/log/codex-tui.log`; look for
`appsignal-mcp-wrapper:` lines when debugging timeouts. The `.env` file is
git-ignored so each developer can customise their helper and secret path.

## n8n API Env Helpers

`~/mcp/bin/n8n-mcp-wrapper` follows the same pattern: it sources `~/mcp/.env`,
checks for `N8N_API_URL`/`N8N_API_KEY`, and if missing invokes
`N8N_API_ENV_HELPER` (defaults to `~/ia.dotfiles/bin/n8n_api_env_helper`). The
helper prints `KEY=VALUE` lines which the wrapper exports before launching the
MCP entrypoint (`~/.n8n-mcp/dist/mcp/index.js`). Optional extras such as
`N8N_BASIC_AUTH_USER`, `N8N_BASIC_AUTH_PASSWORD`, `N8N_API_TIMEOUT`, and
`N8N_API_PATH` are also forwarded when available.

## n8n MCP

- Integrate: `mcp integrate n8n` (or target a client: `--client=codex|goose|claude`).
- Inspector: `npx @modelcontextprotocol/inspector --command node --args "$HOME/.n8n-mcp/build/index.js"`.
- Optional env: export `N8N_HOST`, `N8N_API_KEY`, `N8N_BASIC_AUTH_USER`, `N8N_BASIC_AUTH_PASSWORD` if your server requires auth.


### Install n8n MCP server
- Install: `mcp install n8n`
- Integrate: `mcp integrate n8n`
