# frozen_string_literal: true

require_relative "lib/mcp_cli/version"

Gem::Specification.new do |spec|
  spec.name          = "mcp_cli"
  spec.version       = McpCli::VERSION
  spec.summary       = "Ruby-based MCP manager and client integrator"
  spec.description   = "Manage curated/non-curated MCPs, integrate with Claude, Codex, Goose, with profiles."
  spec.authors       = ["t"]
  spec.files         = Dir["bin/*", "lib/**/*", "README.md"]
  spec.executables   = ["mcp"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "thor", "~> 1.2"
  spec.add_dependency "toml-rb", "~> 2.0"
end
