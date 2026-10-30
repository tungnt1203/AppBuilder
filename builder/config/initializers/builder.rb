Rails.application.configure do
  # Where new projects are created, and the app every project starts from.
  # Tests keep their apps' folders to themselves, outside the repository and never next to the
  # real ones (still named projects/, which transcripts shorten paths by).
  test_root = Pathname(Dir.tmpdir).join("appbuilder-test", "projects") if Rails.env.test?
  config.x.projects_root = Pathname(ENV.fetch("PROJECTS_ROOT", test_root || Rails.root.join("../projects")))
  # New projects are storefronts (Platform v1): they sell through the Storefront API.
  config.x.template_path = Pathname(ENV.fetch("TEMPLATE_PATH", Rails.root.join("../storefront")))

  # The Platform's address for browsers and published storefronts' links and photos (the API's
  # image URLs), and where storefronts in containers reach it (a preview in the Docker sandbox, a
  # storefront on this machine's ONCE): this machine's localhost is host.docker.internal there.
  config.x.platform_url = ENV.fetch("PLATFORM_URL") { "http://localhost:#{ENV.fetch("PORT", 3000)}" unless Rails.env.test? }
  config.x.platform_url_from_containers = ENV.fetch("PLATFORM_URL_FROM_CONTAINERS") do
    config.x.platform_url&.sub(%r{//(localhost|127\.0\.0\.1)\b}, "//host.docker.internal")
  end
  # Emails' links (a new order, the morning's summary, invitations) go to the same address.
  if (url = config.x.platform_url)
    uri = URI(url)
    config.action_mailer.default_url_options = { host: uri.host, port: (uri.port unless uri.port == uri.default_port), protocol: uri.scheme }.compact
  end
  # Development only lets in localhost; storefronts in containers call it by their name for it,
  # and Stripe and Printify by its public one (a tunnel's). (An empty list lets every host in, so
  # production's is left alone.)
  if config.hosts.any?
    config.hosts.concat([ config.x.platform_url, config.x.platform_url_from_containers ].compact.map { |url| URI(url).host })
  end

  # Claude credentials for the agent, from `claude setup-token`: the environment wins, then
  # `bin/rails credentials:edit` with claude: { oauth_token: ... }. Without either, the local
  # `claude` login is used. Only the agent process ever receives it (see ProjectShell).
  config.x.claude_oauth_token = ENV["CLAUDE_CODE_OAUTH_TOKEN"].presence || Rails.application.credentials.dig(:claude, :oauth_token)

  # "sdk" runs runner/index.mjs (the Claude Agent SDK) and is interactive: the agent can ask
  # questions mid-turn, take extra messages and be stopped. It needs `npm install` in runner/
  # and a token or API key. "cli" runs the local `claude -p` and can only be stopped.
  # Where each project's code and agent run: "docker" (a container per project, see
  # app/models/sandbox.rb and `bin/sandbox build`) or "local" (this machine). Tests run
  # locally unless they pick one.
  config.x.sandbox = ENV.fetch("SANDBOX", Rails.env.test? ? "local" : "docker")
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

  # How many apps a member's account may have; administrators have no limit.
  config.x.apps_per_account = Integer(ENV.fetch("APPS_PER_ACCOUNT", 2))

  # What a member's apps may spend on the agent each calendar month, in US dollars
  # (MONTHLY_BUDGET_USD=none for no limit); administrators have no limit.
  config.x.monthly_budget_usd = ENV.fetch("MONTHLY_BUDGET_USD", "20").then { |value| Float(value) unless value == "none" }

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
