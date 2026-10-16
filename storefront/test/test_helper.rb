ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "storefront_kit/testing"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # Every test talks to a Platform in memory (StorefrontKit::Testing::FakeApi): @platform. Set its
    # data up (@platform.shop_data, @platform.products_data) and read what was sent (@platform.requests).
    setup { @platform = StorefrontKit.api = StorefrontKit::Testing::FakeApi.new }
    teardown { StorefrontKit.api = nil }
  end
end
