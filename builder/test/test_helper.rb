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

    # Version histories with these commits, newest first, without a repository on disk.
    def with_versions(*shas)
      original = ProjectHistory.instance_method(:versions)
      versions = shas.map { |sha| ProjectHistory::Version.new(sha:, subject: "Version #{sha}", committed_at: Time.current) }
      original_tree = ProjectHistory.instance_method(:current_tree)
      ProjectHistory.define_method(:versions) { |limit: 30| versions.first(limit) }
      ProjectHistory.define_method(:current_tree) { "tree-#{shas.first}" }
      yield
    ensure
      ProjectHistory.define_method(:versions, original)
      ProjectHistory.define_method(:current_tree, original_tree)
    end

    def with_agent_backend(backend)
      original, Rails.configuration.x.agent_backend = Rails.configuration.x.agent_backend, backend
      yield
    ensure
      Rails.configuration.x.agent_backend = original
    end
  end
end
