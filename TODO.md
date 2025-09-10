# MCP CLI (Ruby) — Next Implementation Steps

Status
- Repo scaffolded at `~/mcp` with CLI, skeleton classes, and initial commit.
- Concept and architecture detailed in dotfiles at `mcp/doc/TODO.md`.

Guiding Principles
- Small, composable classes; strict separation of concerns.
- Idempotent, testable operations (no-churn writes, safe merges, backups).
- Minimal dependencies; shell out to external CLIs only when required.

Milestone Map
1) Foundations: config handlers + tests
2) Registry sources: curated, mcp-get, Smithery + caching
3) Clients: Codex (TOML), Goose (YAML), Claude (CLI + fallback)
4) Servers: CuratedServer, GenericServer + Node/Python strategies
5) Profiles: read/write, active profile, env overlay
6) Integrator orchestration + CLI integration
7) Search/list/info/prompt end-to-end
8) Packaging, docs, plug-in points

Detailed Tasks

1. Configuration Layer (with tests)
- BaseConfig
  - Atomic write (tmp file + rename), `.bak` backup on first write.
  - Merge strategy contract (deep merge, stable key ordering when possible).
  - Acceptance: unit tests validate read/write/merge and backups.
- TomlConfig (Codex)
  - Read/write `~/.codex/config.toml` (fallback `~/.codex/mcp.toml`).
  - Helpers: `upsert_server(name, command:, env_keys:)`, `remove_server(name)`.
  - Acceptance: round-trip test updates only the intended keys; idempotent.
- YamlConfig (Goose)
  - Read/write `${XDG_CONFIG_HOME:-~/.config}/goose/config.yaml`.
  - Helpers: `upsert_extension(name, command:, env_keys:)`, `remove_extension(name)`.
  - Acceptance: preserves unrelated content, sorts keys consistently; idempotent.
- JsonConfig (Claude fallback)
  - Read/write `~/.claude/settings.json` as a fallback (if needed by adapter).
  - Helpers minimal; primarily for future-proofing.

2. Registry Sources
- Curated (YAML)
  - Load bundled YAML (gem data) + user overrides `~/.config/mcp/curated/*.yml`.
  - Validate schema (name, description, install/integrate/uninstall specs).
  - Acceptance: can list and resolve multiple curated MCPs.
- mcp-get
  - Detect availability; implement `search`, `list`, `find` by shelling out.
  - Cache results to `~/.config/mcp/cache/mcp_get.json` with TTL.
  - Acceptance: offline mode serves from cache; graceful when CLI absent.
- Smithery
  - Detect CLI; implement `search`, `list`, `find` similarly; cache JSON.
  - Acceptance: aggregated search merges curated + mcp-get + Smithery results.

3. Clients (Adapters)
- Common
  - BaseClient contract: `integrate(server, profile)`, `disintegrate`, `list`.
  - Use Config handlers; consistent logging + dry-run mode.
- Codex
  - Upsert/remove servers in TOML; support env key references.
  - Acceptance: matches current dotfiles behavior and round-trips cleanly.
- Goose
  - Upsert/remove extensions in YAML; include `--env-key` style semantics.
  - Acceptance: mirrors dotfiles `goose/integrate` behavior.
- Claude
  - Prefer `claude mcp add/remove/list`; fallback to settings file if needed.
  - Acceptance: idempotent operations; informative errors when CLI unavailable.

4. Servers
- CuratedServer
  - Execute curated install/uninstall actions (scripts or inline shell blocks).
  - Provide info/prompt paths where declared.
- GenericServer
  - Strategy order: mcp-get -> Smithery -> npm/npx (Node) -> pip/pipx (Python)
    -> Docker/native/manual guidance.
  - Detect platform tools; produce actionable guidance when not available.
- NodeServer / PythonServer
  - Encapsulate package manager details; expose `install/update/start_cmd`.

5. Profiles
- Model + Manager
  - Store in `~/.config/mcp/profiles.yml` with `active` pointer in config.yml.
  - `list`, `create`, `use`, `delete` with validation; optional secret refs.
- CLI
  - `mcp profile list|create|use|delete`; show active profile.
- Acceptance: profile overlay applied in `integrate` and `disintegrate`.

6. Integrator
- Orchestrate server->client integration using profile env overlays.
- Batch support for multiple names; stop-on-error with summary report.
- Acceptance: end-to-end tests with sample curated definitions.

7. CLI Completion
- Wire commands to services; consistent UX and error messages.
- `list`: combine curated + installed markers per client.
- `info`/`prompt`: show docs; pick from curated or well-known locations.
- `search`: aggregated across sources; show source origin.

8. Packaging & Tooling
- Add RSpec + sample tests; RuboCop with lightweight rules.
- Add `bin/setup` and `bin/dev` for developer ergonomics.
- Add GitHub Actions (Ruby 3.2+) for lint + test.
- Gem packaging metadata; version bump scripts.

Data Models & Schemas
- Curated YAML (minimal schema):
  name: gmail
  description: Gmail integration
  install:
    script: ~/.gmail-mcp/install
  integrate:
    clients:
      claude:
        cmd: ["claude", "mcp", "add", "gmail", "--", "node", "~/.gmail-mcp/dist/index.js"]
      codex:
        upsert: { server: gmail, command: "node ~/.gmail-mcp/dist/index.js", env_keys: ["GMAIL_*"] }
      goose:
        upsert: { extension: gmail, command: "node ~/.gmail-mcp/dist/index.js", env_keys: ["GMAIL_*"] }
  uninstall:
    remove_paths: ["~/.gmail-mcp"]

Acceptance Criteria Snapshot
- Config handlers pass read/merge/write tests and are no-op when unchanged.
- Registry returns results even offline (from cache) and merges sources.
- Clients perform idempotent upserts and list currently integrated MCPs.
- Integrator applies selected profile envs and reports a clear summary.

Open Questions
- Secrets: integrate with gopass/OS keychain? (defer; design hooks only)
- Windows support: how much to support initially? (likely N/A for v0.1)
- Docker strategy: add optional support in GenericServer.

Initial Task Ordering (2–3 day sprint)
1) Implement BaseConfig + TomlConfig with tests (Codex first).
2) Implement YamlConfig (Goose) + upsert helpers.
3) Implement Curated source + Resolver wiring; add 1–2 example YAMLs.
4) Implement Codex + Goose clients with idempotent integrate/disintegrate.
5) Wire CLI `integrate`, `disintegrate`, `list` using curated + clients.

Stretch in following sprint
- Add mcp-get + Smithery sources with caching and `search` aggregation.
- Add Claude adapter via CLI; implement Profiles manager and overlay.
- Add Generic/Node/Python server strategies and minimal install paths.
