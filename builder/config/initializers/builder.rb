Rails.application.configure do
  # Where new projects are created, and the app every project starts from.
  config.x.projects_root = Pathname(ENV.fetch("PROJECTS_ROOT", Rails.root.join("../projects")))
  config.x.template_path = Pathname(ENV.fetch("TEMPLATE_PATH", Rails.root.join("../template")))

  # Claude credentials for the agent, from `claude setup-token`: the environment wins, then
  # `bin/rails credentials:edit` with claude: { oauth_token: ... }. Without either, the local
  # `claude` login is used. Only the agent process ever receives it (see ProjectShell).
  config.x.claude_oauth_token = ENV["CLAUDE_CODE_OAUTH_TOKEN"].presence || Rails.application.credentials.dig(:claude, :oauth_token)

  # "sdk" runs runner/index.mjs (the Claude Agent SDK) and is interactive: the agent can ask
  # questions mid-turn, take extra messages and be stopped. It needs `npm install` in runner/
  # and a token or API key. "cli" runs the local `claude -p` and can only be stopped.
  # Where each project's code and agent run: "local" (this machine) or "docker" (a container
  # per project, see app/models/sandbox.rb and `bin/sandbox build`).
  config.x.sandbox = ENV.fetch("SANDBOX", "local")
  config.x.sandbox_image = ENV.fetch("SANDBOX_IMAGE", "appbuilder-sandbox")
  config.x.sandbox_cpus = ENV.fetch("SANDBOX_CPUS", "2")
  config.x.sandbox_memory = ENV.fetch("SANDBOX_MEMORY", "2g")
  config.x.sandbox_gems_volume = ENV.fetch("SANDBOX_GEMS_VOLUME", "appbuilder-gems")
  config.x.sandboxes_root = Pathname(ENV.fetch("SANDBOXES_ROOT", Rails.root.join(Rails.env.test? ? "tmp/sandboxes" : "storage/sandboxes")))

  # The Docker sandbox has the Agent SDK built in.
  sdk_installed = config.x.sandbox == "docker" || Rails.root.join("runner/node_modules/@anthropic-ai/claude-agent-sdk").exist?
  sdk_ready = sdk_installed && (config.x.claude_oauth_token.present? || ENV["ANTHROPIC_API_KEY"].present?)
  config.x.agent_backend = ENV.fetch("AGENT_BACKEND") { sdk_ready ? "sdk" : "cli" }
  config.x.agent = config_for(:agent)

  # Free stock photo searches for the agent's bin/images: from the environment or
  # `bin/rails credentials:edit` with unsplash: { access_key: ... }, pexels: { api_key: ... }
  # and pixabay: { api_key: ... }. Without them it uses Openverse, which needs no key but
  # has fewer good photos.
  config.x.stock_photo_keys = {
    "UNSPLASH_ACCESS_KEY" => ENV["UNSPLASH_ACCESS_KEY"].presence || Rails.application.credentials.dig(:unsplash, :access_key),
    "PEXELS_API_KEY" => ENV["PEXELS_API_KEY"].presence || Rails.application.credentials.dig(:pexels, :api_key),
    "PIXABAY_API_KEY" => ENV["PIXABAY_API_KEY"].presence || Rails.application.credentials.dig(:pixabay, :api_key)
  }.compact

  # Each project's preview server gets its own port, counting up from here.
  config.x.first_preview_port = Integer(ENV.fetch("FIRST_PREVIEW_PORT", 4001))

  # Publishing: images go to this registry, apps run on ONCE at <subdomain>.<publish domain>,
  # and a backup is taken before every update.
  config.x.registry = ENV.fetch("REGISTRY", "localhost:5050")
  config.x.once_bin = ENV.fetch("ONCE_BIN", "once")
  config.x.publish_domain = ENV.fetch("PUBLISH_DOMAIN", "localhost")
  config.x.backups_root = Pathname(ENV.fetch("BACKUPS_ROOT", Rails.root.join(Rails.env.test? ? "tmp/backups" : "../backups")))

  # Screenshots of each preview for the apps grid, taken with headless Chrome when it is installed.
  config.x.chrome_bin = ENV.fetch("CHROME_BIN", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
  config.x.thumbnails_root = Pathname(ENV.fetch("THUMBNAILS_ROOT", Rails.root.join(Rails.env.test? ? "tmp/thumbnails" : "storage/thumbnails")))
end
