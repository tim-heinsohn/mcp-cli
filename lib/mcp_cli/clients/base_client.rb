# frozen_string_literal: true

module McpCli
  module Clients
    class BaseClient
      def integrate(server:, profile: nil); raise NotImplementedError; end
      def disintegrate(server:, profile: nil); raise NotImplementedError; end
      def list; []; end
    end
  end
end
