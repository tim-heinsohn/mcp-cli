# frozen_string_literal: true

require 'fileutils'

module McpCli
  module Config
    class BaseConfig
      attr_reader :path, :backup

      def initialize(path:, backup: true)
        @path = File.expand_path(path)
        @backup = backup
      end

      # Read and return a Ruby Hash representation of the config file.
      # Implemented in subclasses.
      def read
        raise NotImplementedError
      end

      # Write a Ruby Hash representation to the config file using an atomic
      # rename. Creates a one-time .bak backup of the original file if enabled.
      def write(data)
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

        if backup && File.exist?(path)
          bak = path + '.bak'
          FileUtils.cp(path, bak) unless File.exist?(bak)
        end

        tmp = path + '.tmp'
        File.open(tmp, 'w', 0o600) { |f| f.write(serialize(data)) }
        FileUtils.mv(tmp, path)
        true
      end

      # Merge two Ruby Hash structures deeply. Right-side values win.
      def deep_merge(left, right)
        return right if left.nil?
        return left if right.nil?

        if left.is_a?(Hash) && right.is_a?(Hash)
          merged = {}
          (left.keys | right.keys).each do |k|
            merged[k] = deep_merge(left[k], right[k])
          end
          merged
        else
          right
        end
      end

      # Optional: subclasses may override to provide deterministic ordering
      # and correct serialization. Base implementation writes as YAML.
      def serialize(_data)
        raise NotImplementedError
      end
    end
  end
end
