# frozen_string_literal: true

require 'fileutils'
require_relative '../config/toml_config'
require_relative 'base_client'

module McpCli
  module Clients
    # Codex MCP client adapter
    # - Manages ~/.codex/config.toml (or ~/.codex/mcp.toml fallback)
    # - Upserts/removes entries under [mcp.servers.<name>]
    # Structure example:
    #   [mcp.servers.gmail]
    #   command = "node ~/.gmail-mcp/dist/index.js"
    #   env_keys = ["GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET"]
    class Codex < BaseClient
      def initialize(config_path: nil)
        @config_path = config_path || default_config_path
        @config = McpCli::Config::TomlConfig.new(path: @config_path)
      end

      # List configured servers (names under [mcp.servers])
      def list
        data = @config.read
        servers = data.dig('mcp', 'servers') || {}
        servers.keys
      end

      # Integrate using a server spec or a simple tuple
      # server: object responding to :name and :metadata (with 'command', 'env_keys')
      # or Hash with keys :name, :command, :env_keys
      def integrate(server: nil, profile: nil, name: nil, command: nil, env_keys: [])
        spec = if server
                 normalize_server_spec(server)
               else
                 { name: name, command: command, env_keys: Array(env_keys) }
               end

        raise ArgumentError, 'name and command are required' if spec[:name].to_s.empty? || spec[:command].to_s.empty?

        upsert_server(spec[:name], command: spec[:command], env_keys: spec[:env_keys] || [])
      end

      # Remove an MCP server by spec or by explicit name
      def disintegrate(server: nil, name: nil)
        server_name = if server
                        normalize_server_spec(server)[:name]
                      else
                        name
                      end
        raise ArgumentError, 'name is required' if server_name.to_s.empty?
        remove_server(server_name)
      end

      # Explicit helpers
      def upsert_server(name, command:, env_keys: [])
        data = @config.read
        data['mcp'] ||= {}
        data['mcp']['servers'] ||= {}
        servers = data['mcp']['servers']
        before = Marshal.dump(servers)

        servers[name] ||= {}
        servers[name]['command'] = command
        servers[name]['env_keys'] = Array(env_keys)

        changed = before != Marshal.dump(servers)
        @config.write(data) if changed
        changed
      end

      def remove_server(name)
        data = @config.read
        return false unless data.dig('mcp', 'servers', name)
        data['mcp']['servers'].delete(name)
        @config.write(data)
        true
      end

      private

      def default_config_path
        codex_dir = File.expand_path('~/.codex')
        FileUtils.mkdir_p(codex_dir)
        primary = File.join(codex_dir, 'config.toml')
        fallback = File.join(codex_dir, 'mcp.toml')
        File.exist?(primary) ? primary : fallback
      end

      def normalize_server_spec(server)
        if server.respond_to?(:name) && server.respond_to?(:metadata)
          md = server.metadata || {}
          { name: server.name, command: md['command'] || md[:command], env_keys: (md['env_keys'] || md[:env_keys] || []) }
        elsif server.is_a?(Hash)
          { name: server[:name] || server['name'], command: server[:command] || server['command'], env_keys: server[:env_keys] || server['env_keys'] || [] }
        else
          raise ArgumentError, 'Unsupported server spec; provide Hash or object(name, metadata)'
        end
      end
    end
  end
end
