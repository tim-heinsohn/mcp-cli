# frozen_string_literal: true

module McpCli
  module Servers
    class CuratedServer < Server
      def initialize(model); @model = model; end
    end
  end
end
