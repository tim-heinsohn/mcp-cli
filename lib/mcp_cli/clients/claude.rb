# frozen_string_literal: true

require 'open3'
require_relative '../util/log'
require_relative 'base_client'

module McpCli
  module Clients
    # Claude MCP client adapter
    # Integrates MCP servers via the `claude mcp` CLI.
    # Supports:
    # - list:    `claude mcp list`
    # - add:     `claude mcp add <name> [--scope user] [-e KEY=VAL ...] -- <cmd ...>`
    # - remove:  `claude mcp remove <name>`
    class Claude < BaseClient
      DEFAULT_SCOPE = 'user'

      def initialize(scope: DEFAULT_SCOPE)
        @scope = scope
      end

      # List MCPs. If scope provided ('user' or 'workspace'), pass through
      # to Claude CLI; otherwise list across both scopes.
      def list(scope: nil)
        args = ['claude', 'mcp', 'list']
        args << "--scope=#{scope}" if scope
        out, _ = run_capture(*args)
        parse_list(out)
      end

      # Return { user: [...], workspace: [...] }
      def list_scopes
        user = list(scope: 'user')
        ws = list(scope: 'workspace')
        if user.empty? && ws.empty?
          combined = list
          { user: combined, workspace: [] }
        else
          { user: user, workspace: ws }
        end
      end

      # Accepts same shape as Codex adapter for consistency
      def integrate(server: nil, profile: nil, name: nil, command: nil, env_keys: [])
        spec = if server
                 normalize_server_spec(server)
               else
                 { name: name, command: command, env_keys: Array(env_keys) }
               end
        raise ArgumentError, 'name and command are required' if blank?(spec[:name]) || blank?(spec[:command])

        cmd = ['claude', 'mcp', 'add', spec[:name]]
        cmd += ['--scope', @scope] if @scope

        requested_keys = Array(spec[:env_keys])
        present = []
        requested_keys.each do |k|
          val = ENV[k]
          if val && !val.empty?
            cmd += ['-e', "#{k}=#{val}"]
            present << k
          end
        end
        missing = requested_keys - present
        unless missing.empty?
          raise ArgumentError, "Missing required env for Claude: #{missing.join(', ')}. Export them and retry."
        end

        cmd << '--'
        # Split command into args respecting simple quotes
        cmd.concat(shellwords(spec[:command]))

        system(*cmd)
      end

      def disintegrate(server: nil, name: nil)
        server_name = if server
                        normalize_server_spec(server)[:name]
                      else
                        name
                      end
        raise ArgumentError, 'name is required' if blank?(server_name)
        system('claude', 'mcp', 'remove', server_name)
      end

      private

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

      def run_capture(*cmd)
        out, err, st = Open3.capture3(*cmd)
        [st.success? ? out : nil, st.success? ? nil : err]
      end

      def parse_list(out)
        names = []
        (out || '').each_line do |line|
          line = line.strip
          next if line.empty? || line.start_with?('Checking')
          # Expect lines like: "name: <cmd> - ✓ Connected"
          if (m = line.match(/^([A-Za-z0-9_-]+):/))
            names << m[1]
          end
        end
        names
      end

      def blank?(s)
        s.nil? || s.to_s.strip.empty?
      end

      # Lightweight shellwords splitter (avoid extra gem deps)
      def shellwords(str)
        return [] if str.nil? || str.empty?
        str.scan(/(?:[^\s\"']+|\"[^\"]*\"|'[^']*')+/).map { |w| w.gsub(/^\"|\"$|^'|'$/, '') }
      end
    end
  end
end
