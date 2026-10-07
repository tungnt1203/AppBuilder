ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/customer_accounts_test_helper"

# Tests run in one language: /admin follows the site's (I18n.default_locale) unless a test sets
# config.x.admin_locale itself, so I18n.t in tests matches what both halves show.
Rails.configuration.x.admin_locale = nil

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
