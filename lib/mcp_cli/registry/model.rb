# frozen_string_literal: true

module McpCli
  module Registry
    class Model
      attr_reader :name, :description, :metadata
      def initialize(name:, description: nil, metadata: {})
        @name = name
        @description = description
        @metadata = metadata
      end
    end
  end
end
