# frozen_string_literal: true

module McpCli
  module Registry
    module Sources
      class Smithery
        def available?
          system("command -v smithery >/dev/null 2>&1")
        end
        def find(name); nil; end
        def list; []; end
        def search(_q); []; end
      end
    end
  end
end
