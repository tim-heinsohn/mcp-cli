# frozen_string_literal: true

module McpCli
  module Profiles
    class Manager
      def list; []; end
      def use(_name); end
      def create(_name, env: {}); end
    end
  end
end
