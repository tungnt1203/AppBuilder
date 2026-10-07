require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Starter
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Shown in the page title, navigation and emails.
    config.x.app_name = "Starter"

    # Customers buy and book without an account by default (a guest checkout). Turn this on when
    # customers should sign up and come back to an account: sign up, sign in, password reset and
    # /account then open, and the site header shows a sign-in link. Off, those pages answer 404.
    config.x.customer_accounts = false

    # Language and time zone of the people using the app. Built-in screens are
    # translated in config/locales (en, vi); rails-i18n covers Rails' own messages.
    config.i18n.available_locales = %i[ en vi ]
    config.i18n.default_locale = :en
    config.time_zone = "UTC"

    config.action_view.default_form_builder = "UiFormBuilder"
  end
end
