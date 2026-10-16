require_relative "boot"

require "rails"
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module StorefrontApp
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])

    # The storefront is in English.
    config.i18n.available_locales = %i[ en ]
    config.i18n.default_locale = :en
    config.time_zone = "UTC"

    config.action_view.default_form_builder = "UiFormBuilder"
  end
end
