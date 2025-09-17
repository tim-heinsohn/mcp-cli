# frozen_string_literal: true

require 'fileutils'
require 'shellwords'
require_relative '../config/toml_config'
require_relative '../registry/resolver'
require_relative '../registry/sources/curated'
require_relative 'base_client'

module McpCli
  module Clients
    class Codex < BaseClient
      BASE_INCLUDE_ONLY = %w[
        PATH
        HOME
        LOGNAME
        USER
        USERNAME
        SHELL
        PWD
        TMP
        TMPDIR
        TEMP
        TERM
        LANG
        LC_*
      ].freeze

      def initialize(config_path: nil)
        @config_path = config_path || default_config_path
        @config = McpCli::Config::TomlConfig.new(path: @config_path)
        @resolver = nil
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

        optional_keys = Array(spec[:optional_env_keys])
        raise ArgumentError, 'name and command are required' if spec[:name].to_s.empty? || spec[:command].to_s.empty?

        tokens = Shellwords.split(spec[:command]).map { |t| expand_path_token(t) }
        raise ArgumentError, 'command must contain an executable' if tokens.empty?
        bin = tokens.shift
        args = tokens

        env_map = {}
        env_map.merge!(spec[:env]) if spec[:env].is_a?(Hash)
        requested_keys = Array(spec[:env_keys])
        missing = requested_keys.select { |k| ENV[k].to_s.empty? && !env_map.key?(k) }
        $stderr.puts("Warning: Missing env for Codex: #{missing.join(', ')}") unless missing.empty?

        ensure_shell_env_policy(env_map.keys + requested_keys + optional_keys)

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
        removed, env_keys = remove_server(server_name)
        prune_shell_env_policy(env_keys) if removed
        removed
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
        servers = data['mcp_servers'] || {}
        server_cfg = servers[name]
        return [false, []] unless server_cfg

        env_keys = env_keys_for(name, server_cfg)
        servers.delete(name)
        data['mcp_servers'] = servers
        @config.write(data)
        [true, env_keys]
      end

      private

      def ensure_shell_env_policy(additional_keys)
        desired = BASE_INCLUDE_ONLY + Array(additional_keys).map(&:to_s)
        data = @config.read
        policy = data['shell_environment_policy']
        policy = {} unless policy.is_a?(Hash)

        changed = false

        if policy['inherit'].to_s.empty?
          policy['inherit'] = 'all'
          changed = true
        end

        unless policy['ignore_default_excludes'] == true
          policy['ignore_default_excludes'] = true
          changed = true
        end

        include_only = Array(policy['include_only']).map(&:to_s)
        desired.each do |key|
          next if key.empty?
          unless include_only.include?(key)
            include_only << key
            changed = true
          end
        end

        # De-duplicate while preserving order (important if config was manually edited).
        deduped = []
        include_only.each { |val| deduped << val unless deduped.include?(val) }
        if deduped != include_only
          include_only = deduped
          changed = true
        end

        policy['include_only'] = include_only unless include_only.empty?

        if changed
          data['shell_environment_policy'] = policy
          @config.write(data)
        end
      end

      def prune_shell_env_policy(keys)
        keys = Array(keys).map(&:to_s).reject(&:empty?)
        return if keys.empty?

        data = @config.read
        policy = data['shell_environment_policy']
        return unless policy.is_a?(Hash)

        include_only = Array(policy['include_only']).map(&:to_s)
        original = include_only.dup

        keys.each do |key|
          next if BASE_INCLUDE_ONLY.include?(key)
          include_only.delete(key)
        end

        return if include_only == original

        if include_only.empty?
          policy.delete('include_only')
        else
          policy['include_only'] = include_only
        end

        data['shell_environment_policy'] = policy
        @config.write(data)
      end

      def env_keys_for(name, server_cfg = nil)
        keys = []

        if server_cfg
          env = server_cfg['env'] || server_cfg[:env]
          keys.concat(env.keys.map(&:to_s)) if env.is_a?(Hash)

          args = server_cfg['args'] || server_cfg[:args]
          Array(args).each_cons(2) do |a, b|
            keys << b if a == '-e'
          end
        end

        keys.concat(curated_env_keys(name))
        keys.map(&:to_s).uniq
      end

      def curated_env_keys(name)
        resolver = cached_resolver
        return [] unless resolver

        model = resolver.resolve(name)
        return [] unless model

        clients = model.metadata && (model.metadata['clients'] || {})
        entry = clients['codex'] || clients[:codex] || {}
        required = Array(entry['env_keys'] || entry[:env_keys])
        optional = Array(entry['optional_env_keys'] || entry[:optional_env_keys])
        (required + optional).map(&:to_s)
      rescue StandardError
        []
      end

      def cached_resolver
        @resolver ||= McpCli::Registry::Resolver.new(
          sources: [McpCli::Registry::Sources::Curated.new]
        )
      end

      def expand_path_token(str)
        return str if str.nil? || str.empty?
        s = str.dup
        s = s.gsub(/\$HOME|\$\{HOME\}/, ENV["HOME"].to_s)
        s = File.expand_path(s) if s.start_with?("~")
        s
      end


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
          { name: server.name, command: md['command'] || md[:command], env_keys: (md['env_keys'] || md[:env_keys] || []), optional_env_keys: (md['optional_env_keys'] || md[:optional_env_keys] || []) }
        elsif server.is_a?(Hash)
          { name: server[:name] || server['name'], command: server[:command] || server['command'], env_keys: server[:env_keys] || server['env_keys'] || [], optional_env_keys: server[:optional_env_keys] || server['optional_env_keys'] || [] }
        else
          raise ArgumentError, 'Unsupported server spec; provide Hash or object(name, metadata)'
        end
      end
    end
  end
end
