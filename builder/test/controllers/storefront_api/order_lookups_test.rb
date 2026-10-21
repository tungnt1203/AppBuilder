require "test_helper"

class StorefrontApi::OrderLookupsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { @api_key = api_key_for }

  test "a buyer gets an email with a link to their orders at the shop, newest first" do
    ActsAsTenant.with_tenant(shops(:cats)) { orders(:shipped).update!(email: "pat@example.com") }

    assert_enqueued_emails 1 do
      api :post, storefront_api_order_lookups_path, params: { email: " Pat@Example.com " }
    end
    assert_response :accepted

    deliver_enqueued_emails
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "pat@example.com" ], mail.to
    assert_equal "Chubby Cat Tees: your orders", mail.subject
    url = mail.text_part.body.to_s[%r{https?://\S+/orders/find/(\S+)}]
    token = url.split("/orders/find/").last
    assert_no_match "pat", url, "the email isn't readable in the link"

    lookup = api(:get, storefront_api_order_lookup_path(token))["order_lookup"]
    assert_response :ok
    assert_equal "pat@example.com", lookup["email"]
    assert_equal [ "#1003", "#1001" ], lookup["orders"].map { |order| order["name"] }
    assert lookup["orders"].first["token"].present?
  end

  test "an email without orders here gets nothing, and the storefront can't tell" do
    assert_no_enqueued_emails do
      api :post, storefront_api_order_lookups_path, params: { email: "nobody@example.com" }
    end
    assert_response :accepted
  end

  test "an email that isn't one is refused" do
    api :post, storefront_api_order_lookups_path, params: { email: "pat" }
    assert_response :unprocessable_entity
    assert_equal "isn't a valid email", response.parsed_body.dig("error", "fields", "email")
  end

  test "a link from another shop, a forged one or an expired one finds nothing" do
    other = ActsAsTenant.with_tenant(shops(:dogs)) { OrderLookup.new("pat@example.com", test: false).token }
    ours = ActsAsTenant.with_tenant(shops(:cats)) { OrderLookup.new("pat@example.com", test: false).token }

    [ other, "#{ours}x", "nonsense" ].each do |token|
      api :get, storefront_api_order_lookup_path(token)
      assert_response :not_found
    end

    travel OrderLookup::EXPIRES_IN + 1.minute do
      api :get, storefront_api_order_lookup_path(ours)
      assert_response :not_found
    end
  end

  test "the preview finds test orders, the published shop real ones" do
    ActsAsTenant.with_tenant(shops(:cats)) do
      orders(:paid).update!(email: "pat@example.com", test: true)
      assert_equal [ "#1002" ], OrderLookup.new("pat@example.com", test: true).orders.map(&:name)
      assert_equal [ "#1001" ], OrderLookup.new("pat@example.com", test: false).orders.map(&:name)
    end
  end

  test "a few asks per email, then it waits" do
    original = Rails.cache.method(:increment)
    Rails.cache.define_singleton_method(:increment) { |name, *rest, **options| name.include?(":lookup:") && name.include?("pat@example.com") ? 4 : original.call(name, *rest, **options) }

    assert_no_enqueued_emails do
      api :post, storefront_api_order_lookups_path, params: { email: "Pat@example.com" }
    end
    assert_response :too_many_requests
    assert_equal "rate_limited", response.parsed_body.dig("error", "code")

    api :post, storefront_api_order_lookups_path, params: { email: "lee@example.com" }
    assert_response :accepted
  ensure
    Rails.cache.define_singleton_method(:increment, original)
  end
end
