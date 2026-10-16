module StorefrontKit
  # Not isolated: its helpers (StorefrontHelper) and controller concern (Storefront) are the app's.
  class Engine < ::Rails::Engine
    config.action_dispatch.rescue_responses.merge!(
      "StorefrontKit::NotFound" => :not_found,
      "StorefrontKit::Unreachable" => :service_unavailable,
      "StorefrontKit::Unauthorized" => :service_unavailable
    )
  end
end
