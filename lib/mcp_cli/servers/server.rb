# frozen_string_literal: true

module McpCli
  module Servers
    class Server
      def install; raise NotImplementedError; end
      def update; raise NotImplementedError; end
      def uninstall; raise NotImplementedError; end
      def info_path; nil; end
      def prompt_path; nil; end
    end
  end
end
