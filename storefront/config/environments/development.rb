require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true
  config.action_controller.perform_caching = Rails.root.join("tmp/caching-dev.txt").exist?

  # The API's answers (and their ETags) are kept here.
  config.cache_store = :memory_store

  config.active_support.deprecation = :log
  config.action_dispatch.verbose_redirect_logs = true
  config.assets.quiet = true
  config.action_view.annotate_rendered_view_with_filenames = true
  config.action_controller.raise_on_missing_callback_actions = true

  # The builder shows the preview in a frame, and owners open it on their phones through a tunnel.
  config.action_dispatch.default_headers.delete("X-Frame-Options")
  config.hosts.push(".ngrok-free.app", ".ngrok-free.dev", ".ngrok.app", ".ngrok.io", ".trycloudflare.com")
end
