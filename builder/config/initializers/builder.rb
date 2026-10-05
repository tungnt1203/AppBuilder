Rails.application.configure do
  # Where new projects are created, and the app every project starts from.
  config.x.projects_root = Pathname(ENV.fetch("PROJECTS_ROOT", Rails.root.join("../projects")))
  config.x.template_path = Pathname(ENV.fetch("TEMPLATE_PATH", Rails.root.join("../template")))

  # "cli" uses the local `claude` command; "sdk" uses runner/index.mjs and ANTHROPIC_API_KEY.
  config.x.agent_backend = ENV.fetch("AGENT_BACKEND") { ENV["ANTHROPIC_API_KEY"].present? ? "sdk" : "cli" }
  config.x.agent = config_for(:agent)

  # Each project's preview server gets its own port, counting up from here.
  config.x.first_preview_port = Integer(ENV.fetch("FIRST_PREVIEW_PORT", 4001))
end
