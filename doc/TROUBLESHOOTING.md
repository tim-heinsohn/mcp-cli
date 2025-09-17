# Codex MCP Troubleshooting

## AppSignal MCP timeout when sandboxed

1. Verify the session is running unsandboxed. Check `~/.codex/config.toml` for `sandbox_mode = "danger-full-access"` or launch Codex with `codex --sandbox danger-full-access`.
2. Confirm Docker connectivity from the same terminal: `docker version` and `docker run --rm -e APPSIGNAL_API_KEY -e USER_AGENT appsignal/mcp --help` should both succeed.
3. Force-stop any lingering AppSignal MCP containers so a fresh run has control: `docker ps --filter ancestor=appsignal/mcp -q | xargs -r docker rm -f`.
4. Quit every Codex UI/process, start a new Codex session, and reproduce the MCP startup.
5. While reproducing, tail `~/.codex/log/codex-tui.log` in another terminal. If timeouts persist, rerun with more logging: `RUST_LOG=codex_mcp=trace codex ...` and attach the trace to the bug report.

### AppSignal MCP still times out after the above checks

Codex 0.36.0 starts MCP servers with a heavily-sanitised environment. By default it keeps only a short allow-list (`PATH`, `HOME`, etc.) and **drops `APPSIGNAL_API_KEY` and `USER_AGENT`** even if they are exported in your shell. Because the AppSignal container is launched with `docker run -e APPSIGNAL_API_KEY -e USER_AGENT ...`, Docker ends up forwarding *empty* values. The MCP server immediately aborts with `Error: APPSIGNAL_API_KEY environment variable is required`, but Codex keeps waiting for an `initialize` response and eventually reports a timeout.

To confirm this is the culprit:

- Run the container with a stripped environment: `env -i PATH="$PATH" HOME="$HOME" docker run -e APPSIGNAL_API_KEY -e USER_AGENT appsignal/mcp --help`. Seeing the `APPSIGNAL_API_KEY environment variable is required` error reproduces the Codex launch context.
- Check `~/.codex/log/codex-tui.log` after a timed-out launch; there will only be `initialize` debug lines and no reply from the server.

**Workarounds until Codex passes the variables through by default:**

1. Launch Codex with explicit overrides so the vars are injected: `codex -c "mcp_servers.appsignal.env={\"APPSIGNAL_API_KEY\":\"$APPSIGNAL_API_KEY\",\"USER_AGENT\":\"$USER_AGENT\"}"`. (Be mindful of shell quoting and avoid committing secrets.)
2. Alternatively, patch `/srv/lib/codex/codex-rs/mcp-client/src/mcp_client.rs` locally to extend `DEFAULT_ENV_VARS` with the required names, rebuild Codex, and relaunch.

After setting either workaround, restart Codex; the AppSignal MCP should respond to the initial `initialize` request within a second and the timeout disappears.

**Wrapper script fallback (2025-09-17 update):** `~/mcp/bin/appsignal-mcp-wrapper` now runs AppSignal for Codex and writes timestamped status lines to stderr, which end up in `~/.codex/log/codex-tui.log`. It loads optional overrides from `~/mcp/.env` (see `~/mcp/.env.sample`) so each developer can point to their own helper script. The flow is:

- If `APPSIGNAL_API_KEY` already exists in the environment Codex passes through, use it as-is.
- Otherwise run `APPSIGNAL_API_KEY_HELPER` (defaults to `~/bin/appsignal_api_key_helper`) and treat its stdout as the secret. This can be any command—wrap your own gopass/1Password/Keeper call here.
- `USER_AGENT` falls back to `codex-mcp-wrapper` when unset.

Check the log for entries like `appsignal-mcp-wrapper: Loaded APPSIGNAL_API_KEY via helper.` to confirm the secret flow. If the helper fails or produces no output, the wrapper exits so Codex surfaces the failure instead of hanging on initialize.

These checks confirm whether the sandbox is still blocking `/var/run/docker.sock`, whether Docker launches at all, and whether the Codex client is ignoring the MCP handshake even when the container responds.
