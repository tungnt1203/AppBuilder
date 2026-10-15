ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/stripe_test_helper"
require_relative "test_helpers/printify_test_helper"
require_relative "test_helpers/meta_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # A shop's data is read inside that shop (acts_as_tenant): tests of it pick the shop first.
    def in_shop(shop = shops(:cats))
      ActsAsTenant.current_tenant = shop
    end

    teardown { ActsAsTenant.current_tenant = nil }

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

    # Apps' folders in a temporary directory, removed afterwards.
    def with_projects_root
      root = Pathname(Dir.mktmpdir)
      original, Rails.configuration.x.projects_root = Rails.configuration.x.projects_root, root
      yield
    ensure
      Rails.configuration.x.projects_root = original
      FileUtils.rm_rf(root)
    end

    def with_sandbox(kind)
      original, Rails.configuration.x.sandbox = Rails.configuration.x.sandbox, kind
      yield
    ensure
      Rails.configuration.x.sandbox = original
    end
  end
end

class ActionDispatch::IntegrationTest
  # A shop's admin (ShopAdmin::*): its data in the test and its paths without naming it each time,
  # shop_admin_order_path(order).
  def in_shop_admin(shop = shops(:cats))
    in_shop(shop)
    self.default_url_options = default_url_options.merge(shop_id: shop)
  end
end
