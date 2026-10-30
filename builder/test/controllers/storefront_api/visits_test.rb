require "test_helper"

class StorefrontApi::VisitsTest < ActionDispatch::IntegrationTest
  test "a visitor's day keeps its furthest step and first source, and the funnel counts each step reached" do
    @api_key = api_key_for
    api :post, storefront_api_visits_path, params: { visitor: "a" * 32, step: "visit", source: "tiktok" }
    assert_response :no_content
    api :post, storefront_api_visits_path, params: { visitor: "a" * 32, step: "cart", source: "google" }
    api :post, storefront_api_visits_path, params: { visitor: "a" * 32, step: "product" }
    api :post, storefront_api_visits_path, params: { visitor: "b" * 32, step: "product", source: "<script>" }

    ActsAsTenant.with_tenant(shops(:cats)) do
      a, b = Visit.order(:step).reverse
      assert_equal [ 3, "tiktok" ], [ a.step, a.source ]
      assert_equal [ 2, "direct" ], [ b.step, b.source ]
      assert_no_match "aaaa", a.visitor, "kept digested"
      assert_equal({ "visit" => 2, "product" => 2, "cart" => 1, "checkout" => 0, "purchase" => 0 }, ShopReport.new.funnel)
      assert_equal 1, ShopReport.new.funnel(source: "tiktok")["cart"]
    end

    api :post, storefront_api_visits_path, params: { visitor: "c" * 32, step: "dance" }
    assert_response :unprocessable_entity
  end

  test "the builder's preview isn't counted" do
    @api_key = api_key_for(kind: "preview")
    api :post, storefront_api_visits_path, params: { visitor: "a" * 32, step: "visit" }
    assert_response :no_content
    assert_equal 0, ActsAsTenant.without_tenant { Visit.count }
  end
end
