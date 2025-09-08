# frozen_string_literal: true

require 'toml-rb'
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
        TomlRB.parse(File.read(path))
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
    end
  end
end
