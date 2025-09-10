# frozen_string_literal: true

require 'fileutils'
require 'shellwords'
require_relative '../config/toml_config'
require_relative 'base_client'

module McpCli
  module Clients
    # Codex MCP client adapter
    # - Manages ~/.codex/config.toml (or ~/.codex/mcp.toml fallback)
    # - Upserts/removes entries under [mcp_servers.<name>]
    # Structure example:
    #   [mcp_servers.appsignal]
    #   command = "docker"
    #   args = ["run","-i","--rm","-e","APPSIGNAL_API_KEY","appsignal/mcp"]
    #   env = { APPSIGNAL_API_KEY = "..." }
    class Codex < BaseClient
      def initialize(config_path: nil)
        @config_path = config_path || default_config_path
        @config = McpCli::Config::TomlConfig.new(path: @config_path)
      end

      # List configured servers (names under [mcp_servers])
      def list
        data = @config.read
        servers = data['mcp_servers'] || {}
        servers.keys
      end

      # Integrate using a server spec or a simple tuple
      # server: object responding to :name and :metadata (with 'command', 'env_keys'|'env'|'args')
      # or Hash with keys :name, :command, :env_keys, :env, :args
      def integrate(server: nil, profile: nil, name: nil, command: nil, env_keys: [])
        spec = if server
                 normalize_server_spec(server)
               else
                 { name: name, command: command, env_keys: Array(env_keys) }
               end

        raise ArgumentError, 'name and command are required' if spec[:name].to_s.empty? || spec[:command].to_s.empty?

        # Convert command string to binary + args for Codex schema
        tokens = Shellwords.split(spec[:command])
        raise ArgumentError, 'command must contain an executable' if tokens.empty?
        bin = tokens.shift
        args = tokens

        # Build env map from explicit env or from env_keys
        env_map = {}
        env_map.merge!(spec[:env]) if spec[:env].is_a?(Hash)
        requested_keys = Array(spec[:env_keys])
        present_keys = []
        requested_keys.each do |k|
          val = ENV[k]
          if val && !val.empty?
            env_map[k] = val
            present_keys << k
          end
        end
        missing = requested_keys - present_keys
        if !missing.empty? && spec[:env].to_h.slice(*missing).empty?
          raise ArgumentError, "Missing required env for Codex: #{missing.join(', ')}. Export them and retry."
        end

        # Default USER_AGENT if not provided; helps certain servers (e.g., AppSignal)
        env_map['USER_AGENT'] ||= 'codex/0.33 (mcp; linux)'

        # If invoking docker run, ensure we pass through env keys to the container
        if bin == 'docker' && args.include?('run')
          env_map.keys.each do |k|
            next if args.each_cons(2).any? { |a,b| a == '-e' && b == k }
            idx = args.rindex { |a| not a.start_with?('-') } || -1
            args.insert(idx, k)
            args.insert(idx, '-e')
          end
        end

        upsert_server(spec[:name], command: bin, args: args, env: env_map)
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

      # Explicit helpers using text replacement to enforce inline env map format
      def upsert_server(name, command:, args: [], env: {})
        path = @config.path
        FileUtils.mkdir_p(File.dirname(path))
        current = File.exist?(path) ? File.read(path) : ""
        block = format_block(name, command, args, env)
        pattern = /^\[mcp_servers\.#{Regexp.escape(name)}\][\s\S]*?(?=^\[|\z)/m
        if current.match?(pattern)
          before = current.dup
          updated = current.sub(pattern, block)
          return false if updated == before
          write_text_atomic(path, updated)
          return true
        else
          sep = current.end_with?("\n") || current.empty? ? "" : "\n"
          updated = current + sep + block + "\n"
          write_text_atomic(path, updated)
          return true
        end
      end

      def remove_server(name)
        path = @config.path
        return false unless File.exist?(path)
        current = File.read(path)
        pattern = /^\[mcp_servers\.#{Regexp.escape(name)}\][\s\S]*?(?=^\[|\z)/m
        return false unless current.match?(pattern)
        updated = current.sub(pattern, "")
        write_text_atomic(path, updated)
        true
      end

      def format_block(name, command, args, env)
        b = []
        b << "[mcp_servers.#{name}]"
        b << %(command = #{command.to_s.inspect})
        unless Array(args).empty?
          arr = Array(args).map { |a| a.to_s.inspect }.join(', ')
          b << %(args = [#{arr}])
        end
        unless env.nil? || env.empty?
          # stable key ordering
          pairs = env.keys.sort.map { |k| %(#{k} = #{env[k].to_s.inspect}) }
          b << %(env = { #{pairs.join(', ')} })
        end
        b.join("\n")
      end

      def write_text_atomic(path, content)
        tmp = path + ".tmp"
        File.open(tmp, 'w', 0o600) { |f| f.write(content) }
        FileUtils.mv(tmp, path)
        File.chmod(0o600, path)
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
