# MCP CLI Repository Review

A comprehensive analysis of the Ruby MCP CLI repository covering architecture, implementation patterns, and improvement opportunities.

## Architecture Assessment

### Strengths
- **Clean separation of concerns**: CLI (Thor), Clients (adapters), Config handlers, Registry sources
- **Sound adapter pattern** for client integrations with consistent BaseClient interface
- **Registry abstraction** enables extensible source discovery (curated, mcp-get, Smithery)
- **Atomic file writes** with backup strategy shows thoughtful data safety

### Areas for Improvement
- **Orchestration Logic**: CLI currently does too much heavy lifting. The `Integrator` class is a stub but should be the service layer coordinating client interactions
- **Duplication**: `normalize_server_spec`, `shellwords`, and env handling repeated across clients suggests need for shared utilities
- **Missing Registry Caching**: Sources lack TTL-based caching, limiting scalability

## Implementation Quality

### Ruby Idioms Done Well
- Consistent use of `frozen_string_literal`, keyword arguments, small focused classes
- Thoughtful file handling with atomic writes and one-time backups

### Technical Debt
- **Inconsistent Return Values**: Claude returns system() boolean, Codex/Goose return "changed" boolean - need unified BaseClient contract
- **Custom Parsing**: Hand-rolled shellwords and TOML fallback when stdlib alternatives exist
- **Error Handling**: Mix of exceptions, return codes, and logging needs standardization

## Lean Implementation Opportunities

### Reduce Low-Level Complexity
- Replace custom `shellwords` with stdlib `Shellwords.split`
- TOML fallback parser risks data loss - either require `toml-rb` or make fallback read-only
- Docker command surgery in Codex is brittle - model docker configs declaratively instead
- Claude list parsing fragile - prefer machine-readable output or robust regex

### Environment Variable Handling
- Current `-e KEY=VAL` approach exposes secrets in process lists
- Consider `-e KEY` (inherit from env) or `.env` file support

## Architecture Revisions Recommended

### 1. Service Layer Pattern
```ruby
# Move orchestration from CLI to service
class Integrator
  def integrate(names:, clients:, resolver:, profile: nil)
    # Batch operations, error handling, reporting
  end
end
```

### 2. Unified Specifications
```ruby
class ServerSpec
  attr_reader :name, :command, :env_keys, :docker_config
  # Canonical representation shared across clients
end
```

### 3. Client Registry
```ruby
class ClientRegistry
  def self.for(name)
    # Dynamic loading, capability matrix
  end
end
```

## Scalability Concerns

- **Performance**: Sequential integration could be slow for many MCPs - consider thread pool
- **Cross-platform**: Custom parsing likely breaks on Windows
- **Growth**: More clients will amplify duplication without shared abstractions

## Quick Wins (Low Risk)

### 1. Replace custom shellwords with stdlib equivalents
**Explanation**: The codebase contains multiple custom implementations of shell word splitting using regex patterns. The Ruby standard library provides `Shellwords.split` which handles edge cases like nested quotes, escaping, and platform differences more robustly.

**Why this helps**: Reduces maintenance burden, eliminates edge-case bugs, and leverages well-tested stdlib code.

**Example**: 
```ruby
# Current custom implementation in multiple files:
def shellwords(str)
  return [] if str.nil? || str.empty?
  str.scan(/(?:[^\s\"']+|\"[^\"]*\"|'[^']*')+/).map { |w| w.gsub(/^\"|\"$|^'|'$/, '') }
end

# Replace with:
require 'shellwords'
Shellwords.split(command_string)
```

### 2. Extract shared utilities for spec normalization and env handling
**Explanation**: The `normalize_server_spec` method is duplicated across Claude, Codex, and Goose clients with slight variations. Similarly, environment variable handling logic is repeated. This creates maintenance overhead and risk of divergent behavior.

**Why this helps**: Centralizes common logic, ensures consistent behavior across clients, and makes testing easier.

**Example**:
```ruby
# Create shared module
module McpCli
  module ServerSpecUtils
    def self.normalize(server)
      # Unified normalization logic
    end
    
    def self.resolve_env_keys(requested_keys, available_env = ENV)
      # Shared environment resolution
    end
  end
end

# Use in clients:
class Claude < BaseClient
  def integrate(server:, **opts)
    spec = ServerSpecUtils.normalize(server)
    # ...
  end
end
```

### 3. Unify BaseClient return contract and error semantics
**Explanation**: Currently, Claude's `integrate` method returns the result of `system()` (boolean indicating command success), while Codex and Goose return a "changed" boolean indicating whether the configuration was modified. This inconsistency makes the interface unpredictable.

**Why this helps**: Provides predictable interface for callers, enables consistent error handling and reporting.

**Example**:
```ruby
# Standardize BaseClient interface
class BaseClient
  IntegrationResult = Struct.new(:success, :changed, :message)
  
  def integrate(server:, profile: nil)
    # All implementations return IntegrationResult
    raise NotImplementedError
  end
end

# Implementation example:
def integrate(server:, profile: nil)
  spec = normalize_server_spec(server)
  changed = upsert_server(spec)
  IntegrationResult.new(true, changed, "Server #{spec[:name]} integrated")
rescue => e
  IntegrationResult.new(false, false, e.message)
end
```

### 4. Add CLI presence detection before calling external tools
**Explanation**: The code calls external CLIs (like `claude mcp list`) without first checking if they're available, leading to cryptic error messages when tools are missing.

**Why this helps**: Provides clear, actionable error messages and graceful degradation.

**Example**:
```ruby
class Claude < BaseClient
  def self.available?
    system('which claude > /dev/null 2>&1')
  end
  
  def list(scope: nil)
    unless self.class.available?
      raise "Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-cli"
    end
    # ... existing logic
  end
end
```

### 5. Implement basic test suite for config round-trips and client operations
**Explanation**: The codebase lacks automated tests, making refactoring risky and regression detection difficult. Basic tests for core operations would provide safety net for improvements.

**Why this helps**: Enables confident refactoring, catches regressions early, documents expected behavior.

**Example**:
```ruby
# spec/config/toml_config_spec.rb
RSpec.describe McpCli::Config::TomlConfig do
  it "round-trips data without changes" do
    original = { 'mcp_servers' => { 'test' => { 'command' => 'echo' } } }
    config = described_class.new(path: '/tmp/test.toml')
    
    config.write(original)
    result = config.read
    
    expect(result).to eq(original)
  end
end
```

## Structural Improvements (Higher Impact)

### 1. Implement proper Integrator - move CLI orchestration logic into service layer
**Explanation**: The CLI class currently contains complex orchestration logic for batch operations, error handling, and client coordination. This violates single responsibility principle and makes the code hard to test. The `Integrator` class exists but is just a stub.

**Why this helps**: Separates presentation logic from business logic, improves testability, enables reuse of integration logic from other interfaces.

**Example**:
```ruby
class Integrator
  def initialize(resolver:, client_registry:)
    @resolver = resolver
    @client_registry = client_registry
  end
  
  def integrate_batch(names:, client_names:, profile: nil)
    results = []
    
    names.each do |name|
      server_spec = @resolver.resolve(name)
      
      client_names.each do |client_name|
        client = @client_registry.for(client_name)
        result = client.integrate(server: server_spec, profile: profile)
        results << { name: name, client: client_name, result: result }
      end
    end
    
    results
  end
end

# CLI becomes thin facade:
class CLI < Thor
  def integrate(*names)
    integrator = build_integrator
    results = integrator.integrate_batch(
      names: names,
      client_names: resolve_clients(options),
      profile: options[:profile]
    )
    
    report_results(results)
  end
end
```

### 2. Add registry caching with TTL for offline operation
**Explanation**: Registry sources like mcp-get and Smithery require network calls but lack caching. This makes the tool slow and unusable offline. The TODO mentions this but it's not implemented.

**Why this helps**: Improves performance, enables offline operation, reduces load on upstream services.

**Example**:
```ruby
class CachedRegistrySource
  def initialize(source:, cache_dir:, ttl_seconds: 3600)
    @source = source
    @cache_file = File.join(cache_dir, "#{source.class.name.downcase}.json")
    @ttl = ttl_seconds
  end
  
  def list
    if cache_fresh?
      load_from_cache
    else
      refresh_cache
    end
  rescue NetworkError
    load_from_cache || []
  end
  
  private
  
  def cache_fresh?
    File.exist?(@cache_file) && 
      (Time.now - File.mtime(@cache_file)) < @ttl
  end
end
```

### 3. Introduce declarative models for ServerSpec, ClientSpec, DockerSpec
**Explanation**: The current implementation manipulates command strings and argument arrays at a low level. This is error-prone and makes it hard to reason about configurations. Declarative models would encapsulate the complexity.

**Why this helps**: Reduces string manipulation errors, centralizes validation logic, makes configurations more testable and composable.

**Example**:
```ruby
class DockerSpec
  attr_reader :image, :pull_policy, :env_keys, :additional_flags
  
  def initialize(image:, pull_policy: :if_missing, env_keys: [], additional_flags: [])
    @image = image
    @pull_policy = pull_policy
    @env_keys = env_keys
    @additional_flags = additional_flags
  end
  
  def to_command(env_values = {})
    cmd = ['docker', 'run', '-i', '--rm']
    cmd += ['--pull=always'] if @pull_policy == :always
    
    @env_keys.each do |key|
      cmd += ['-e', env_values.key?(key) ? "#{key}=#{env_values[key]}" : key]
    end
    
    cmd += @additional_flags
    cmd << @image
  end
end

# Usage:
docker_spec = DockerSpec.new(
  image: 'appsignal/mcp',
  pull_policy: :always,
  env_keys: ['APPSIGNAL_API_KEY', 'USER_AGENT']
)
command = docker_spec.to_command(ENV)
```

### 4. Plugin architecture for dynamic client/source loading
**Explanation**: As the ecosystem grows, users may want to add custom clients or registry sources. The current architecture requires code changes. A plugin system would enable extensibility without modifying core code.

**Why this helps**: Enables community contributions, supports custom workflows, reduces maintenance burden on core team.

**Example**:
```ruby
module McpCli
  class PluginRegistry
    def self.register_client(name, klass)
      @clients ||= {}
      @clients[name] = klass
    end
    
    def self.client_for(name)
      @clients[name] || raise "Unknown client: #{name}"
    end
    
    def self.load_plugins
      Dir[File.expand_path('~/.config/mcp/plugins/**/*.rb')].each do |file|
        require file
      end
    end
  end
end

# Plugin example (~/.config/mcp/plugins/custom_client.rb):
class CustomClient < McpCli::Clients::BaseClient
  def integrate(server:, profile: nil)
    # Custom integration logic
  end
end

McpCli::PluginRegistry.register_client('custom', CustomClient)
```

## Edge Cases and Risks

- **Claude CLI absent**: detect early, emit actionable guidance, and fall back (if supported) rather than parsing nil output
- **Minimal TOML fallback**: could drop unknown sections/keys on write. Danger for users with hand-edited files
- **Workspace/global scope**: disintegrate logic tries both; ensure messages and exit codes reflect actual state clearly
- **Installed marker heuristic**: `~/.<name>-mcp` can mislead. Consider deriving "installed" exclusively from client configs unless a real install step exists
- **YAML dumping**: may reorder keys; if users care, provide stable ordering or preserve comments (hard with YAML)

## Alternatives to Consider

- Keep minimal deps but demand toml-rb as hard dep to avoid unsafe fallback
- For docker-based servers, model them explicitly instead of mutating free-form commands
- Consider a plugin mechanism (Ruby require hooks) for clients/sources if community growth is a goal

## Overall Assessment

This is a **well-architected foundation** with clear separation of concerns and sound design patterns. The main issues are:

- **Drift toward imperative low-level operations** instead of declarative models
- **Missing orchestration layer** (Integrator as intended)
- **Duplication that will compound** as more clients are added

The codebase shows good Ruby practices and thoughtful design decisions around data safety and modularity. With the suggested refactoring toward more declarative models and proper service layer implementation, this could become a very robust and maintainable CLI tool.

The TODO.md shows excellent planning and the current implementation aligns well with the stated principles of minimal dependencies, idempotent operations, and composable design.

## Recommended Implementation Order

1. **Quick Wins first** - These provide immediate value with minimal risk
2. **Service layer refactoring** - Move orchestration logic to Integrator
3. **Declarative models** - Introduce ServerSpec, DockerSpec, etc.
4. **Plugin architecture** - Add extensibility for future growth
5. **Registry caching** - Improve performance and offline capability

This approach allows for incremental improvement while maintaining backward compatibility and reducing the risk of introducing regressions.