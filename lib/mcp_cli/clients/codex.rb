# frozen_string_literal: true

require 'fileutils'
require 'shellwords'
require_relative '../config/toml_config'
require_relative 'base_client'

module McpCli
  module Clients
    class Codex < BaseClient
      def initialize(config_path: nil)
        @config_path = config_path || default_config_path
        @config = McpCli::Config::TomlConfig.new(path: @config_path)
      end

      def list
        data = @config.read
        servers = data['mcp_servers'] || {}
        servers.keys
      end

      def integrate(server: nil, profile: nil, name: nil, command: nil, env_keys: [])
        spec = if server
                 normalize_server_spec(server)
               else
                 { name: name, command: command, env_keys: Array(env_keys) }
               end

        raise ArgumentError, 'name and command are required' if spec[:name].to_s.empty? || spec[:command].to_s.empty?

        tokens = Shellwords.split(spec[:command])
        raise ArgumentError, 'command must contain an executable' if tokens.empty?
        bin = tokens.shift
        args = tokens

        env_map = {}
        env_map.merge!(spec[:env]) if spec[:env].is_a?(Hash)
        requested_keys = Array(spec[:env_keys])
        missing = requested_keys.select { |k| ENV[k].to_s.empty? && !env_map.key?(k) }
        $stderr.puts("Warning: Missing env for Codex: #{missing.join(', ')}") unless missing.empty?

        if bin == 'docker' && args.include?('run')
          image_name = args.last || ""
          is_local_image = image_name.end_with?(':local')
          
          if !is_local_image && !args.include?('--pull=always')
            run_idx = args.index('run')
            insert_at = run_idx ? run_idx + 1 : 0
            args.insert(insert_at, '--pull=always')
          end
          
          (env_map.keys + requested_keys).uniq.each do |k|
            next if args.each_cons(2).any? { |a,b| a == '-e' && b == k }
            idx = args.rindex { |a| not a.start_with?('-') } || -1
            args.insert(idx, k)
            args.insert(idx, '-e')
          end
        end

        upsert_server(spec[:name], command: bin, args: args, env: env_map)
      end

      def disintegrate(server: nil, name: nil)
        server_name = if server
                        normalize_server_spec(server)[:name]
                      else
                        name
                      end
        raise ArgumentError, 'name is required' if server_name.to_s.empty?
        remove_server(server_name)
      end
      def upsert_server(name, command:, args: [], env: {})
        data = @config.read
        data['mcp_servers'] ||= {}

        new_server_config = { 'command' => command }
        new_server_config['args'] = args if args && !args.empty?
        new_server_config['env']  = env  if env  && !env.empty?

        current = (data['mcp_servers'][name] || {}).dup
        current.delete('args') if current['args'].is_a?(Array) && current['args'].empty?
        current.delete('env')  if current['env'].is_a?(Hash) && current['env'].empty?
        return false if current == new_server_config

        data['mcp_servers'][name] = new_server_config
        @config.write(data)
        true
      end

      def remove_server(name)
        data = @config.read
        return false unless data.dig('mcp_servers', name)
        
        data['mcp_servers'].delete(name)
        @config.write(data)
        return true
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
