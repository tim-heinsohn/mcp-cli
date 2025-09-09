# frozen_string_literal: true

require 'yaml'
require_relative '../model'

module McpCli
  module Registry
    module Sources
      class Curated
        DEFAULT_DIRS = [
          File.expand_path('../../../../curated', __dir__),
          File.expand_path('~/.config/mcp/curated')
        ].freeze

        def initialize(dirs: DEFAULT_DIRS)
          @dirs = dirs.uniq
          @cache = nil
        end

        def find(name)
          load_all.find { |m| m.name == name }
        end

        def list
          load_all.map(&:name)
        end

        def search(q)
          q = (q || '').downcase
          load_all.select { |m| m.name.downcase.include?(q) || (m.description || '').downcase.include?(q) }
        end

        private

        def load_all
          return @cache if @cache
          models = []
          @dirs.each do |dir|
            next unless Dir.exist?(dir)
            Dir[File.join(dir, '*.{yml,yaml}')].sort.each do |file|
              begin
                data = YAML.safe_load(File.read(file)) || {}
                name = data['name'] || File.basename(file, '.*')
                desc = data['description']
                clients = data['clients'] || {}
                models << McpCli::Registry::Model.new(name: name, description: desc, metadata: { 'clients' => clients })
              rescue => e
                warn "[curated] failed to load #{file}: #{e.message}"
              end
            end
          end
          @cache = models
        end
      end
    end
  end
end
