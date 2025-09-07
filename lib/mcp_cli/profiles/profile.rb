# frozen_string_literal: true

module McpCli
  module Profiles
    class Profile
      attr_reader :name, :env
      def initialize(name:, env: {})
        @name = name
        @env = env
      end
    end
  end
end
