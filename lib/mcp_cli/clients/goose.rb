# frozen_string_literal: true

require 'fileutils'
require_relative '../config/yaml_config'
require_relative 'base_client'

module McpCli
  module Clients
    # Goose MCP client adapter
    # - Manages ~/.config/goose/config.yaml
    # - Upserts/removes entries under extensions:<name>
    # Structure example (stdio):
    # extensions:
    #   gmail:
    #     enabled: true
    #     type: stdio
    #     name: gmail
    #     cmd: node
    #     args: ["~/.gmail-mcp/dist/index.js"]
    #     env_keys: ["GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET"]
    class Goose < BaseClient
      def initialize(config_path: nil)
        @config_path = config_path || default_config_path
        @config = McpCli::Config::YamlConfig.new(path: @config_path)
      end

      def list
        data = @config.read
        (data['extensions'] || {}).keys
      end

      def integrate(server: nil, profile: nil, name: nil, command: nil, env_keys: [])
        spec = if server
                 normalize_server_spec(server)
               else
                 { name: name, command: command, env_keys: Array(env_keys) }
               end
        raise ArgumentError, 'name and command are required' if blank?(spec[:name]) || blank?(spec[:command])

        bin, *args = shellwords(spec[:command])
        raise ArgumentError, 'command must have an executable' if blank?(bin)

        data = @config.read
        data['extensions'] ||= {}
        before = Marshal.dump(data['extensions'][spec[:name]])

        data['extensions'][spec[:name]] = {
          'enabled' => true,
          'type' => 'stdio',
          'name' => spec[:name],
          'cmd' => bin,
          'args' => args,
        }
        envs = Array(spec[:env_keys])
        data['extensions'][spec[:name]]['env_keys'] = envs unless envs.empty?

        changed = before != Marshal.dump(data['extensions'][spec[:name]])
        @config.write(data) if changed
        changed
      end

      def disintegrate(server: nil, name: nil)
        server_name = if server
                        normalize_server_spec(server)[:name]
                      else
                        name
                      end
        raise ArgumentError, 'name is required' if blank?(server_name)
        data = @config.read
        return false unless data.dig('extensions', server_name)
        data['extensions'].delete(server_name)
        @config.write(data)
        true
      end

      private

      def default_config_path
        root = ENV['XDG_CONFIG_HOME'] && !ENV['XDG_CONFIG_HOME'].empty? ? ENV['XDG_CONFIG_HOME'] : File.expand_path('~/.config')
        dir = File.join(root, 'goose')
        FileUtils.mkdir_p(dir)
        File.join(dir, 'config.yaml')
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

      def blank?(s)
        s.nil? || s.to_s.strip.empty?
      end

      # Lightweight shellwords splitter
      def shellwords(str)
        return [] if str.nil? || str.empty?
        str.scan(/(?:[^\s\"']+|\"[^\"]*\"|'[^']*')+/).map { |w| w.gsub(/^\"|\"$|^'|'$/, '') }
      end
    end
  end
end
