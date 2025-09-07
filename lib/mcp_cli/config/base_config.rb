# frozen_string_literal: true

module McpCli
  module Config
    class BaseConfig
      def read; raise NotImplementedError; end
      def write(_data); raise NotImplementedError; end
      def merge(_data); raise NotImplementedError; end
    end
  end
end
