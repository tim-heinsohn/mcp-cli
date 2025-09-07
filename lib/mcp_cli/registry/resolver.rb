# frozen_string_literal: true

module McpCli
  module Registry
    class Resolver
      def initialize(sources: [])
        @sources = sources
      end

      def resolve(name)
        @sources.each do |src|
          model = src.find(name)
          return model if model
        end
        nil
      end

      def list
        @sources.flat_map { |s| s.list }
      end

      def search(query)
        @sources.flat_map { |s| s.search(query) }
      end
    end
  end
end
