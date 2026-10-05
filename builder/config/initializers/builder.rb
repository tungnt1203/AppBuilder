Rails.application.configure do
  # Where new projects are created, and the app every project starts from.
  config.x.projects_root = Pathname(ENV.fetch("PROJECTS_ROOT", Rails.root.join("../projects")))
  config.x.template_path = Pathname(ENV.fetch("TEMPLATE_PATH", Rails.root.join("../template")))

  # Claude credentials for the agent, from `claude setup-token`: the environment wins, then
  # `bin/rails credentials:edit` with claude: { oauth_token: ... }. Without either, the local
  # `claude` login is used. Only the agent process ever receives it (see ProjectShell).
  config.x.claude_oauth_token = ENV["CLAUDE_CODE_OAUTH_TOKEN"].presence || Rails.application.credentials.dig(:claude, :oauth_token)

  # "cli" uses the local `claude` command; "sdk" uses runner/index.mjs and ANTHROPIC_API_KEY.
  config.x.agent_backend = ENV.fetch("AGENT_BACKEND") { ENV["ANTHROPIC_API_KEY"].present? ? "sdk" : "cli" }
  config.x.agent = config_for(:agent)

  # Each project's preview server gets its own port, counting up from here.
  config.x.first_preview_port = Integer(ENV.fetch("FIRST_PREVIEW_PORT", 4001))

  # Publishing: images go to this registry, apps run on ONCE at <slug>.<publish domain>,
  # and a backup is taken before every update.
  config.x.registry = ENV.fetch("REGISTRY", "localhost:5050")
  config.x.once_bin = ENV.fetch("ONCE_BIN", "once")
  config.x.publish_domain = ENV.fetch("PUBLISH_DOMAIN", "localhost")
  config.x.backups_root = Pathname(ENV.fetch("BACKUPS_ROOT", Rails.root.join("../backups")))
end
