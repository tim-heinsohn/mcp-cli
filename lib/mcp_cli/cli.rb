# frozen_string_literal: true

require "thor"
require_relative "clients/codex"

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

      if cmd.nil? || cmd.strip.empty?
        say_error "--command is required until registry integration is implemented"
        return 1
      end

      successes = []
      failures = []
      names.each do |n|
        begin
          changed = client.integrate(name: n, command: cmd, env_keys: env_keys)
          successes << [n, changed]
        rescue => e
          failures << [n, e.message]
        end
      end

      successes.each do |(n, changed)|
        say "codex: upsert #{n} (#{changed ? 'changed' : 'no-op'})"
      end
      failures.each do |(n, msg)|
        say_error "codex: failed #{n}: #{msg}"
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
        say "codex: remove #{n} (#{removed ? 'removed' : 'not present'})"
      end
      0
    end

    desc "uninstall NAME...", "Uninstall MCP server(s)"
    def uninstall(*names)
      puts "TODO: uninstall #{names.join(', ')}"
    end

    desc "list", "List available MCP servers"
    def list
      puts "TODO: list registry entries"
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
        else
          say_error "Unsupported client '#{name}'. Use --client=codex for now."
          nil
        end
      end

      def say_error(msg)
        $stderr.puts "Error: #{msg}"
      end
    end
  end
end
