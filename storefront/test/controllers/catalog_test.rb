require "test_helper"

class CatalogTest < ActionDispatch::IntegrationTest
  test "the home page shows the theme's headline, the collections and the newest products" do
    get root_path
    assert_response :success
    assert_select "h1", "Tees for people who love a chubby cat"
    assert_select "a[href=?]", "/collections/cats", text: "Cats"
    assert_select "a[href=?]", "/products/cat-tee"
    assert_select "header a[href=?]", "/pages/about", text: "About"
    assert_select "footer a[href=?]", "/policies/refund"
    assert_select "div", text: "Free shipping over $50"
  end

  test "a shop without products says they're coming, and tells the owner how in the preview" do
    @platform.products_data = []
    @platform.shop_data["preview"] = true
    get root_path
    assert_select "p", /first products are on their way/
    assert_select "p", /Only you see this/
  end

  test "the product page: the picked variant, swatches, size guide, reviews, what to know before buying" do
    get product_path("cat-tee", options: %w[ White S ])
    assert_response :success
    assert_select "h1", "Cat Tee"
    assert_select "input[name=variant_id][value='103']"
    assert_select "input[type=radio][name='options[0]'][value=White][checked]"
    assert_select "span[style*='#ffffff']"
    assert_select "button", "Size guide"
    assert_select "td", "34"
    assert_select "li", /Printed just for you/
    assert_select "#reviews p", "Soft and cute."
    assert_select "script[type='application/ld+json']", /"sku":"TEE-101"/
  end

  test "searches and sorts, and a collection lists its products" do
    get products_path(q: "mug", sort: "title")
    assert_select "a[href=?]", "/products/morning-mug"
    assert_select "a[href=?]", "/products/cat-tee", count: 0
    assert_includes @platform.requests, [ :products, { q: "mug", collection: nil, sort: "title", page: nil } ]

    get collection_path("cats")
    assert_select "h1", "Cats"
    assert_select "a[href=?]", "/products/cat-tee"
    get collection_path("new")
    assert_select "h1", "New"
  end

  test "the owner's pages and policies" do
    get page_path("about")
    assert_select "h1", "About us"
    assert_select "summary", "How long?"

    get policy_path("refund")
    assert_select "p", "Returns within 30 days."
  end

  test "what isn't there is a 404" do
    get product_path("nope")
    assert_response :not_found
    get page_path("nope")
    assert_response :not_found
  end

  test "when the Platform can't be reached the shop says it'll be right back" do
    def @platform.shop = raise(StorefrontKit::Unreachable.new("down"))
    get root_path
    assert_response :service_unavailable
    assert_select "h1", "We'll be right back"
  end

  test "the product feed for ad catalogs has one item per variant" do
    get products_feed_path
    assert_response :success
    assert_equal 5, response.body.scan("<item>").size
    assert_includes response.body, "<g:sale_price>24.00 USD</g:sale_price>"
    assert_includes response.body, "<g:id>TEE-102</g:id>"
  end
end
