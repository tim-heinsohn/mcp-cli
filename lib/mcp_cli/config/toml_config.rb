# frozen_string_literal: true

begin
  require 'toml-rb'
rescue LoadError
  # Optional dependency; we will fall back to a minimal parser when absent.
end
require_relative 'base_config'

module McpCli
  module Config
    # Generic TOML configuration handler.
    #
    # This class is purposefully unaware of any specific client's schema.
    # Callers inject the target file path and operate on returned Hash data.
    class TomlConfig < BaseConfig
      # Read TOML into a Ruby Hash; returns {} when file does not exist.
      def read
        return {} unless File.exist?(path)
        content = File.read(path)
        if defined?(TomlRB)
          TomlRB.parse(content)
        else
          parse_minimal(content)
        end
      end

      # Serialize a Ruby Hash into TOML text.
      def serialize(data)
        TomlRB.dump(data)
      end

      # Merge the provided Hash patch into current content and write.
      # Returns the merged data.
      def merge_and_write(patch)
        current = read
        merged = deep_merge(current, patch)
        write(merged)
        merged
      end

      def serialize(data)
        if defined?(TomlRB)
          TomlRB.dump(data)
        else
          dump_minimal(data)
        end
      end

      private

      def dump_minimal(data)
        out = +""
        servers = (data || {}).fetch('mcp_servers', {})
        servers.each do |name, cfg|
          out << "[mcp_servers.#{name}]\n"
          if (cmd = cfg['command'] || cfg[:command])
            out << %(command = #{cmd.to_s.inspect}\n)
          end
          if (args = cfg['args'] || cfg[:args]) && !args.empty?
            arr = Array(args).map { |a| a.to_s.inspect }.join(', ')
            out << %(args = [#{arr}]\n)
          end
          if (env = cfg['env'] || cfg[:env]) && !env.empty?
            pairs = env.keys.sort.map { |k| %(#{k} = #{env[k].to_s.inspect}) }
            out << %(env = { #{pairs.join(', ')} }\n)
          end
          out << "\n"
        end
        out
      end

      private

      # Minimal parser used when toml-rb is not available. Only extracts
      # top-level [mcp_servers.<name>] sections into a Hash structure so that
      # adapters can list configured servers without a full TOML parser.
      def parse_minimal(content)
        data = {}
        servers = {}
        content.each_line do |line|
          line = line.strip
          next if line.empty? || line.start_with?('#')
          if (m = line.match(/^\[mcp_servers\.([^\]]+)\]/))
            servers[m[1]] = {}
          end
        end
        data['mcp_servers'] = servers unless servers.empty?
        data
      end
    end
  end
end
