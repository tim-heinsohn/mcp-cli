# frozen_string_literal: true

module McpCli
  module Registry
    module Sources
      class Curated
        def initialize(dir: File.expand_path("~/.config/mcp/curated"))
          @dir = dir
        end
        def find(name); nil; end
        def list; []; end
        def search(_q); []; end
      end
    end
  end
end
