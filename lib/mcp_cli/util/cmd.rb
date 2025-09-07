# frozen_string_literal: true

module McpCli
  module Util
    module Cmd
      module_function
      def run(*cmd)
        system(*cmd)
      end
    end
  end
end
