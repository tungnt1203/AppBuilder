ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Whether apps count as built, without a version history on disk.
    def with_built_apps(built = true)
      original = Project.instance_method(:built?)
      Project.define_method(:built?) { built }
      yield
    ensure
      Project.define_method(:built?, original)
    end

    def with_agent_backend(backend)
      original, Rails.configuration.x.agent_backend = Rails.configuration.x.agent_backend, backend
      yield
    ensure
      Rails.configuration.x.agent_backend = original
    end
  end
end
