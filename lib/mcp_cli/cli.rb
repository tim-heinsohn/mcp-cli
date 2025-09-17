# frozen_string_literal: true

require "thor"
require "fileutils"
require_relative "clients/codex"
require_relative "clients/claude"
require_relative "clients/goose"
require_relative "registry/resolver"
require_relative "registry/sources/curated"

module McpCli
  class ProfileCLI < Thor
    # ... (rest of ProfileCLI is unchanged)
    desc "list", "List profiles"
    def list(*filter_names)
      puts "TODO: list profiles"
    end

    desc "use NAME", "Use a profile (activate overlay)"
    def use(name)
      puts "TODO: activate profile #{name}"
    end

    desc "create NAME", "Create a profile"
    method_option :env, type: :hash, default: {}, desc: "Env vars for profile"
    def create(name)
      puts "TODO: create profile #{name} with env: #{options[:env].inspect}"
    end
  end

  class CLI < Thor
    desc "install NAME...", "Install MCP server(s)"
    def install(*names)
      names.each do |name|
        case name
        when "appsignal"
          install_appsignal
        when "n8n"
          install_n8n
        else
          say_error "Installation logic for '#{name}' is not defined."
        end
      end
    end

    desc "update [NAME...]", "Update MCP server(s)"
    def update(*names)
      puts "TODO: update #{names.join(', ')} (all if none)"
    end

    # ... (rest of the file is unchanged)
    desc "integrate NAME...", "Integrate MCP server(s) with clients (scope flags affect Claude only; Codex/Goose are global-only)"
    method_option :client, type: :string, desc: "Target client (claude|codex|goose|all)", default: "all"
    method_option :profile, type: :string, desc: "Profile to use"
    method_option :command, type: :string, desc: "Command to start the MCP server"
    method_option :env_key, type: :array, banner: "KEY [KEY ...]", desc: "Env keys passed through to the server"
    method_option :global, type: :boolean, aliases: ['-g'], desc: "Claude: integrate in global (user) scope (default)"
    method_option :workspace, type: :boolean, aliases: ['-w'], desc: "Claude: integrate in workspace scope (current dir)"
    def integrate(*names)
      if names.empty?
        say_error "No MCP names provided" and return 1
      end

      scope = resolve_scope_flag(options)
      clients = if options[:client].to_s.downcase == 'all' or options[:client].to_s.strip.empty?
                  %w[codex goose claude]
                else
                  [options[:client].to_s.downcase]
                end
      cmd = options[:command]
      env_keys = Array(options[:env_key]).compact
      resolver = McpCli::Registry::Resolver.new(sources: [McpCli::Registry::Sources::Curated.new])

      failures = []
      names.each do |n|
        begin
          model = nil
          spec_cmd = nil
          if cmd && !cmd.strip.empty?
            spec_cmd = { name: n, command: cmd, env_keys: env_keys }
          else
            model = resolver.resolve(n)
            raise "No curated spec found for '#{n}' and no --command provided" unless model
          end
          clients.each do |client_name|
            begin
              spec_for = spec_cmd || curated_spec_for(model, client_name, extra_env: env_keys)
              client_obj = case client_name
                           when 'codex' then McpCli::Clients::Codex.new
                           when 'goose' then McpCli::Clients::Goose.new
                           when 'claude' then McpCli::Clients::Claude.new(scope: scope)
                           else
                             say_error "Unsupported client '#{client_name}'"; next
                           end
              changed = client_obj.integrate(server: spec_for)
              action = (client_name == 'claude') ? 'add' : 'upsert'
              say "#{client_name}: #{action} #{n} (#{changed ? 'changed' : 'ok'})"
            rescue => e
              failures << "#{client_name}:#{n} -> #{e.message}"
              say_error "#{client_name}: failed #{n}: #{e.message}"
            end
          end
        rescue => e
          failures << "#{n} -> #{e.message}"
          say_error "failed #{n}: #{e.message}"
        end
      end
      failures.empty? ? 0 : 1
    end

    desc "disintegrate NAME...", "Remove MCP server(s) from clients (scope flags affect Claude only; Codex/Goose are global-only)"
    method_option :client, type: :string, desc: "Target client (claude|codex|goose|all)", default: "all"
    method_option :global, type: :boolean, aliases: ['-g'], desc: "Claude: remove from global (user) scope (default)"
    method_option :workspace, type: :boolean, aliases: ['-w'], desc: "Claude: remove from workspace scope (current dir)"
    def disintegrate(*names)
      if names.empty?
        say_error "No MCP names provided" and return 1
      end
      scope = resolve_scope_flag(options)
      clients = if options[:client].to_s.downcase == 'all' || options[:client].to_s.strip.empty?
                  %w[claude codex goose]
                else
                  [options[:client].to_s.downcase]
                end
      names.each do |n|
        clients.each do |c|
          case c
          when 'claude'
            if scope == 'workspace'
              cu = McpCli::Clients::Claude.new(scope: 'workspace')
              removed_ws = cu.disintegrate(name: n)
              say "claude:workspace remove #{n} (#{removed_ws ? 'removed' : 'not present'})"
            elsif scope == 'user'
              cu = McpCli::Clients::Claude.new(scope: 'user')
              removed_user = cu.disintegrate(name: n)
              say "claude:global remove #{n} (#{removed_user ? 'removed' : 'not present'})"
              # Fallback: try workspace if global not present
              unless removed_user
                cw = McpCli::Clients::Claude.new(scope: 'workspace')
                removed_ws = cw.disintegrate(name: n)
                say "claude:workspace remove #{n} (#{removed_ws ? 'removed' : 'not present'})"
              end
            else
              # both (defensive)
              cu = McpCli::Clients::Claude.new(scope: 'user')
              removed_user = cu.disintegrate(name: n)
              say "claude:global remove #{n} (#{removed_user ? 'removed' : 'not present'})"
              cw = McpCli::Clients::Claude.new(scope: 'workspace')
              removed_ws = cw.disintegrate(name: n)
              say "claude:workspace remove #{n} (#{removed_ws ? 'removed' : 'not present'})"
            end
          when 'codex'
            cdx = McpCli::Clients::Codex.new
            removed = cdx.disintegrate(name: n)
            say "codex: remove #{n} (#{removed ? 'removed' : 'not present'})"
          when 'goose'
            gs = McpCli::Clients::Goose.new
            removed = gs.disintegrate(name: n)
            say "goose: remove #{n} (#{removed ? 'removed' : 'not present'})"
          else
            say_error "Unsupported client '#{c}'"
          end
        end
      end
      0
    end

    desc "uninstall NAME...", "Uninstall MCP server(s)"
    def uninstall(*names)
      puts "TODO: uninstall #{names.join(', ')}"
    end

    desc "list [MCP ...]", "List available MCP servers (optionally filter by MCP names; use -g/-w to filter Claude scope; Codex/Goose are global-only)"
    method_option :global, type: :boolean, aliases: ['-g'], desc: "Show only global (user) Claude scope"
    method_option :workspace, type: :boolean, aliases: ['-w'], desc: "Show only workspace Claude scope (current dir)"
    def list(*filter_names)
      curated_source = McpCli::Registry::Sources::Curated.new
      curated_models = curated_source.models
      curated_names = curated_models.map(&:name)
      desc_map = curated_models.each_with_object({}) { |m, h| h[m.name] = m.description.to_s }

      codex = safe_list { McpCli::Clients::Codex.new.list }
      goose = safe_list { McpCli::Clients::Goose.new.list }
      claude_scopes = safe_list { McpCli::Clients::Claude.new.list_scopes }
      claude_user = Array(claude_scopes[:user])
      claude_ws = Array(claude_scopes[:workspace])

      scope = resolve_scope_flag(options, default: 'both')
      names_all = case scope
              when 'user' then (curated_names + codex + goose + claude_user).uniq.sort
              when 'workspace' then (curated_names + codex + goose + claude_ws).uniq.sort
              else (curated_names + codex + goose + claude_user + claude_ws).uniq.sort
              end

      names = (filter_names && !filter_names.empty?) ? (names_all & filter_names) : names_all

      rows = []
      rows << ["MCP", "Installed", "Claude", "Codex", "Goose", "Description"]
      names.each do |n|
        installed = installed_marker(n, codex, goose, claude_user + claude_ws)
        claude_mark = case scope
                      when 'workspace'
                        claude_ws.include?(n) ? 'x' : '—'
                      when 'user'
                        claude_user.include?(n) ? 'X' : '—'
                      else
                        mark_claude(n, claude_user, claude_ws)
                      end
        codex_mark = case scope
                     when 'workspace' then '—'
                     else mark_global(codex.include?(n))
                     end
        goose_mark = case scope
                     when 'workspace' then '—'
                     else mark_global(goose.include?(n))
                     end
        rows << [n, installed, claude_mark, codex_mark, goose_mark, desc_map[n] || ""]
      end
      print_table(rows, indent: 2)
    end

    desc "info NAME", "Show MCP info"
    def info(name)
      puts "TODO: show info for #{name}"
    end

    desc "prompt NAME", "Show MCP Claude prompt help"
    def prompt(name)
      puts "TODO: show prompt for #{name}"
    end

    desc "search QUERY", "Search in curated, mcp-get, Smithery"
    def search(*query)
      puts "TODO: search for '#{query.join(' ')}'"
    end

    desc "profile SUBCOMMAND ...", "Manage profiles"
    subcommand "profile", ProfileCLI

    no_commands do
      def install_appsignal
        repo_url = "https://github.com/appsignal/mcp"
        install_dir = "/srv/lib/appsignal-mcp"
        FileUtils.mkdir_p(File.dirname(install_dir))

        say "Installing appsignal MCP to #{install_dir}..."

        if Dir.exist?(install_dir)
          say "Directory exists, pulling latest changes..."
          system("git", "-C", install_dir, "pull")
        else
          say "Cloning repository..."
          system("git", "clone", repo_url, install_dir)
        end

        patch_target = File.join(install_dir, "src/index.ts")
        if File.exist?(patch_target)
          say "Applying patch to src/index.ts..."
          content = File.read(patch_target)
          
          old_axios_config = 'headers: {\n    Authorization: `Bearer ${API_KEY}`,\n    "Content-Type": "application/json",\n  },'
          new_axios_config = 'headers: {\n    Authorization: `Bearer ${API_KEY}`,
    "User-Agent": process.env.USER_AGENT,
    "Content-Type": "application/json",
  },'

          if content.include?(new_axios_config)
            say "Already patched."
          else
            updated_content = content.sub(old_axios_config, new_axios_config)
            File.write(patch_target, updated_content)
            say "Patch applied."
          end
        else
            say_error "Could not find #{patch_target} to patch."
            return
        end

        say "Building local docker image (appsignal/mcp:local)..."
        build_success = system("docker", "build", "--no-cache", "-t", "appsignal/mcp:local", install_dir)

        if build_success
            say "Docker image built successfully."
            say "Run `mcp integrate appsignal` to activate it."
        else
            say_error "Docker build failed."
        end
      end

      def install_n8n
        repo_url = "https://github.com/czlonkowski/n8n-mcp.git"
        install_dir = File.expand_path("~/.n8n-mcp")

        FileUtils.mkdir_p(install_dir)
        say "Installing n8n MCP to #{install_dir}..."

        if Dir.exist?(File.join(install_dir, ".git"))
          say "Directory exists, pulling latest changes..."
          system("git", "-C", install_dir, "pull") or raise "git pull failed"
        else
          say "Cloning repository..."
          system("git", "clone", repo_url, install_dir) or raise "git clone failed"
        end

        Dir.chdir(install_dir) do
          say "Installing dependencies (npm install)..."
          system("npm", "install") or raise "npm install failed"

          say "Building server (npm run build)..."
          system("npm", "run", "build") or raise "npm run build failed"

          say "Initializing node documentation (npm run rebuild)..."
          system("npm", "run", "rebuild") or raise "npm run rebuild failed"
        end

        say "✅ n8n MCP Server installed successfully!"
        say "Next: run 'mcp integrate n8n' to add it to your clients."
      end
      def resolve_scope_flag(opts, default: 'user')
        g = opts[:global] ? 1 : 0
        w = opts[:workspace] ? 1 : 0
        if g + w > 1
          say_error "--global and --workspace are mutually exclusive"
          exit 1
        end
        if g == 1
          'user'
        elsif w == 1
          'workspace'
        else
          default
        end
      end
      def resolve_client(name)
        case (name || '').downcase
        when 'codex'
          McpCli::Clients::Codex.new
        when 'claude'
          McpCli::Clients::Claude.new
        when 'goose'
          McpCli::Clients::Goose.new
        else
          say_error "Unsupported client '#{name}'. Use --client=codex for now."
          nil
        end
      end

      def say_error(msg)
        $stderr.puts "Error: #{msg}"
      end

      def curated_spec_for(model, client_name, extra_env: [])
        clients = model.metadata.fetch('clients', {})
        client_cfg = clients[(client_name || '').downcase] || clients[(client_name || '').capitalize]
        raise "Curated spec missing for client '#{client_name}'" unless client_cfg
        cmd = client_cfg['command'] || client_cfg[:command]
        envs = Array(client_cfg['env_keys'] || client_cfg[:env_keys]) | Array(extra_env)
        optional_envs = Array(client_cfg['optional_env_keys'] || client_cfg[:optional_env_keys])
        {
          name: model.name,
          command: cmd,
          env_keys: envs,
          optional_env_keys: optional_envs
        }
      end

      def mark(bool)
        bool ? 'x' : '—'
      end

      def installed_marker(name, codex, goose, claude)
        dir = File.expand_path("~/.#{name}-mcp")
        mark(Dir.exist?(dir) || codex.include?(name) || goose.include?(name) || claude.include?(name))
      end

      def safe_list
        yield
      rescue StandardError
        []
      end

      def mark_claude(name, user_list, ws_list)
        return 'X' if user_list.include?(name)
        return 'x' if ws_list.include?(name)
        '—'
      end

      # Global-only clients (Codex, Goose) render uppercase X
      def mark_global(bool)
        bool ? 'X' : '—'
      end
    end
  end
end
