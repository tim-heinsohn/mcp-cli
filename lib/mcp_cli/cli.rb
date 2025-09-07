# frozen_string_literal: true

require "thor"

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
    method_option :client, type: :string, desc: "Target client (claude|codex|goose)"
    method_option :profile, type: :string, desc: "Profile to use"
    def integrate(*names)
      puts "TODO: integrate #{names.join(', ')} for client=#{options[:client]} profile=#{options[:profile]}"
    end

    desc "disintegrate NAME...", "Remove MCP server(s) from clients"
    method_option :client, type: :string, desc: "Target client (claude|codex|goose)"
    def disintegrate(*names)
      puts "TODO: disintegrate #{names.join(', ')} for client=#{options[:client]}"
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
  end
end
