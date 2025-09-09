# frozen_string_literal: true

require 'yaml'
require_relative 'base_config'

module McpCli
  module Config
    # Generic YAML configuration handler. Unaware of client schema.
    class YamlConfig < BaseConfig
      def read
        return {} unless File.exist?(path)
        YAML.safe_load(File.read(path), aliases: true) || {}
      end

      def serialize(data)
        YAML.dump(data)
      end

      def merge_and_write(patch)
        current = read
        merged = deep_merge(current, patch)
        write(merged)
        merged
      end
    end
  end
end
