require "test_helper"

class DemoCatalog::RefreshJobTest < ActiveJob::TestCase
  test "the shop's demo products are made again from its project's request, the old ones gone" do
    projects(:shop).update!(shop: shops(:cats))
    projects(:shop).messages.create!(role: :user, body: "A shop of tees for people who run with their dogs")
    old = ActsAsTenant.with_tenant(shops(:cats)) { DemoCatalog.add! && Product.where(demo: true).pluck(:id) }
    asked = nil

    original = DemoCatalog::Niche.method(:for)
    DemoCatalog::Niche.define_singleton_method(:for) { |request| asked = request and nil }
    DemoCatalog::RefreshJob.perform_now(shops(:cats))

    assert_equal "A shop of tees for people who run with their dogs", asked
    ActsAsTenant.with_tenant(shops(:cats)) do
      assert_empty Product.where(id: old)
      assert Product.where(demo: true).exists?
    end
  ensure
    DemoCatalog::Niche.define_singleton_method(:for, original)
  end
end
