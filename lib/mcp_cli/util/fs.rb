# frozen_string_literal: true

module McpCli
  module Util
    module FS
      module_function
      def ensure_dir(path)
        Dir.mkdir(path) unless Dir.exist?(path)
      end
    end
  end
end
