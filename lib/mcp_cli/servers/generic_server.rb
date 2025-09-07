# frozen_string_literal: true

module McpCli
  module Servers
    class GenericServer < Server
      def initialize(model); @model = model; end
    end
  end
end
