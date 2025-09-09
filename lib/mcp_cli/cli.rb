# frozen_string_literal: true

require "thor"
require_relative "clients/codex"
require_relative "clients/claude"
require_relative "clients/goose"
require_relative "registry/resolver"
require_relative "registry/sources/curated"

module McpCli
  class ProfileCLI < Thor
    desc "list", "List profiles"
    def list
      puts "TODO: list profiles"
    end

    desc "use NAME", "Use a profile (activate overlay)"
    def use(name)
      puts "TODO: activate profile #{name}"
    end

    desc "create NAME", "Create a profile"
    method_option :env, type: :hash, default: {}, desc: "Env vars for profile"
    def create(name)
      puts "TODO: create profile #{name} with env: #{options[:env].inspect}"
    end
  end

  class CLI < Thor
    desc "install NAME...", "Install MCP server(s)"
    def install(*names)
      puts "TODO: install #{names.join(', ')}"
    end

    desc "update [NAME...]", "Update MCP server(s)"
    def update(*names)
      puts "TODO: update #{names.join(', ')} (all if none)"
    end

    desc "integrate NAME...", "Integrate MCP server(s) with clients"
    method_option :client, type: :string, desc: "Target client (claude|codex|goose)", default: "codex"
    method_option :profile, type: :string, desc: "Profile to use"
    method_option :command, type: :string, desc: "Command to start the MCP server"
    method_option :env_key, type: :array, banner: "KEY [KEY ...]", desc: "Env keys passed through to the server"
    def integrate(*names)
      if names.empty?
        say_error "No MCP names provided" and return 1
      end

      client = resolve_client(options[:client]) or return 1
      cmd = options[:command]
      env_keys = Array(options[:env_key]).compact
      resolver = McpCli::Registry::Resolver.new(sources: [McpCli::Registry::Sources::Curated.new])

      successes = []
      failures = []
      names.each do |n|
        begin
          spec = nil
          if cmd && !cmd.strip.empty?
            spec = { name: n, command: cmd, env_keys: env_keys }
          else
            model = resolver.resolve(n)
            if model
              spec = curated_spec_for(model, options[:client], extra_env: env_keys)
            else
              raise "No curated spec found for '#{n}' and no --command provided"
            end
          end
          changed = client.integrate(server: spec)
          successes << [n, changed]
        rescue => e
          failures << [n, e.message]
        end
      end

      successes.each do |(n, changed)|
        say "#{options[:client]}: upsert #{n} (#{changed ? 'changed' : 'no-op'})"
      end
      failures.each do |(n, msg)|
        say_error "#{options[:client]}: failed #{n}: #{msg}"
      end

      failures.empty? ? 0 : 1
    end

    desc "disintegrate NAME...", "Remove MCP server(s) from clients"
    method_option :client, type: :string, desc: "Target client (claude|codex|goose)", default: "codex"
    def disintegrate(*names)
      if names.empty?
        say_error "No MCP names provided" and return 1
      end
      client = resolve_client(options[:client]) or return 1
      names.each do |n|
        removed = client.disintegrate(name: n)
        say "#{options[:client]}: remove #{n} (#{removed ? 'removed' : 'not present'})"
      end
      0
    end

    desc "uninstall NAME...", "Uninstall MCP server(s)"
    def uninstall(*names)
      puts "TODO: uninstall #{names.join(', ')}"
    end

    desc "list", "List available MCP servers"
    def list
      resolver = McpCli::Registry::Resolver.new(sources: [McpCli::Registry::Sources::Curated.new])
      curated = resolver.list

      codex = begin
        McpCli::Clients::Codex.new.list
      rescue => _
        []
      end
      goose = begin
        McpCli::Clients::Goose.new.list
      rescue => _
        []
      end
      claude = begin
        McpCli::Clients::Claude.new.list
      rescue => _
        []
      end

      names = (curated + codex + goose + claude).uniq.sort
      names.each do |n|
        tags = []
        tags << 'curated' if curated.include?(n)
        tags << 'codex' if codex.include?(n)
        tags << 'goose' if goose.include?(n)
        tags << 'claude' if claude.include?(n)
        say sprintf("%-20s %s", n, tags.join(', '))
      end
    end

    desc "info NAME", "Show MCP info"
    def info(name)
      puts "TODO: show info for #{name}"
    end

    desc "prompt NAME", "Show MCP Claude prompt help"
    def prompt(name)
      puts "TODO: show prompt for #{name}"
    end

    desc "search QUERY", "Search in curated, mcp-get, Smithery"
    def search(*query)
      puts "TODO: search for '#{query.join(' ')}'"
    end

    desc "profile SUBCOMMAND ...", "Manage profiles"
    subcommand "profile", ProfileCLI
    no_commands do
      def resolve_client(name)
        case (name || '').downcase
        when 'codex'
          McpCli::Clients::Codex.new
        when 'claude'
          McpCli::Clients::Claude.new
        when 'goose'
          McpCli::Clients::Goose.new
        else
          say_error "Unsupported client '#{name}'. Use --client=codex for now."
          nil
        end
      end

      def say_error(msg)
        $stderr.puts "Error: #{msg}"
      end

      def curated_spec_for(model, client_name, extra_env: [])
        clients = model.metadata.fetch('clients', {})
        client_cfg = clients[(client_name || '').downcase] || clients[(client_name || '').capitalize]
        raise "Curated spec missing for client '#{client_name}'" unless client_cfg
        cmd = client_cfg['command'] || client_cfg[:command]
        envs = Array(client_cfg['env_keys'] || client_cfg[:env_keys]) | Array(extra_env)
        { name: model.name, command: cmd, env_keys: envs }
      end
    end
  end
end
