# frozen_string_literal: true

module McpCli
  module Util
    module Log
      module_function
      def info(msg); puts msg; end
      def warn(msg); $stderr.puts msg; end
    end
  end
end
