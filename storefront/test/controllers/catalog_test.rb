require "test_helper"

class CatalogTest < ActionDispatch::IntegrationTest
  test "the home page shows the theme's headline, the collections and the newest products" do
    get root_path
    assert_response :success
    assert_select "h1", "Tees for people who love a chubby cat"
    assert_select "a[href=?]", "/collections/cats", text: "Cats" do
      assert_select "img[src=?]", "https://cdn.example/cat-card.webp"
    end
    assert_select "a[href=?]", "/products/cat-tee"
    assert_select "header a[href=?]", "/pages/about", text: "About"
    assert_select "footer a[href=?]", "/policies/refund"
    assert_select "div", text: "Free shipping over $50"
  end

  test "the home page's photo and words come from the theme's file until the storefront is published" do
    @platform.shop_data["theme_settings"] = {}
    defaults = [ { "key" => "hero_title", "type" => "text", "default" => "Cats, printed" },
                 { "key" => "hero_image", "type" => "image", "default" => "https://images.unsplash.com/photo-1" } ]
    with_theme_file(defaults) { get root_path }
    assert_select "h1", "Cats, printed"
    assert_select "img[src=?]", "https://images.unsplash.com/photo-1"

    @platform.shop_data["theme_settings"] = { "hero_title" => "Set by the owner", "hero_image" => nil }
    with_theme_file(defaults) { get root_path }
    assert_select "h1", "Set by the owner"
    assert_select "img[src=?]", "https://images.unsplash.com/photo-1", count: 0
  end

  test "until the owner picks a home page photo, the newest products' own photos fill the first screen" do
    tee = @platform.products_data.first
    @platform.products_data = 3.times.map do |index|
      tee.merge("slug" => "tee-#{index}", "image" => tee["image"].merge("id" => index, "large" => "https://cdn.example/tee-#{index}.webp"))
    end
    get root_path
    assert_select "section:first-of-type h1", "Tees for people who love a chubby cat"
    assert_select "section:first-of-type img[src=?]", "https://cdn.example/tee-0.webp"
    assert_select "section:first-of-type img[src=?]", "https://cdn.example/tee-2.webp"

    @platform.products_data = @platform.products_data.first(2)
    get root_path
    assert_select "section:first-of-type img", count: 0
  end

  test "a product page says where it is in the shop and pages through its photos" do
    get product_path("cat-tee")
    assert_select "nav[aria-label=Breadcrumb]" do
      assert_select "a[href='/']", "Home"
      assert_select "a[href='/collections/cats']", "Cats"
      assert_select "li[aria-current=page]", "Cat Tee"
    end
    assert_select "button[data-action='gallery#next'][aria-label=?]", "Next photo"
    assert_select "[data-gallery-target=counter]", "1 / 2"
    assert_select "#buy [data-controller=quantity] input[name=quantity][value='1'][min='1']"
  end

  test "what the owner sets in the theme: logo, brand color, button, socials; benefits they can turn off" do
    @platform.shop_data["theme_settings"] = { "logo" => "https://cdn.example/logo.png", "brand_color" => "#7a1f2b", "hero_button" => "See the cats",
      "instagram_url" => "https://instagram.com/chubbycat", "show_benefits" => false }
    get root_path
    assert_select "header a[href='/'] img[src=?][alt=?]", "https://cdn.example/logo.png", "Chubby Cat Tees"
    assert_select "style", /--color-brand-600: #7a1f2b;/
    assert_select "a[href='/products']", /See the cats/
    assert_select "footer a[href=?]", "https://instagram.com/chubbycat", text: "Instagram"
    assert_select "li", text: /Secure checkout/, count: 0

    @platform.shop_data["theme_settings"] = { "brand_color" => "red;}</style><script>", "show_benefits" => true }
    get root_path
    assert_select "style", count: 0
    assert_select "li", text: /Secure checkout/
  end

  test "product cards say From for a range, the was price and how much a sale saves" do
    get products_path
    assert_select "a[href='/products/cat-tee']" do
      assert_select "span", "From $24.00"
      assert_select "s", "$30.00"
      assert_select "span", "-20%"
    end
    assert_select "a[href='/products/morning-mug'] span", "$15.00"
  end

  test "the header lists the collections, and checkout keeps only the logo and the cart" do
    get root_path
    assert_select "header nav a[href='/collections/cats']", minimum: 1

    post cart_items_path, params: { variant_id: 101, quantity: 1 }
    get new_checkout_path
    assert_select "header nav", count: 0
    assert_select "header a#cart-link"
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

    get collection_path("cats", sort: "price_asc")
    assert_select "h1", "Cats"
    assert_includes @platform.requests, [ :products, { q: nil, collection: "cats", sort: "price_asc", page: nil } ]
    assert_select "a[href=?]", "/products/cat-tee"
    get collection_path("new")
    assert_select "h1", "New"

    get products_path(q: "zzz")
    assert_select "p", /Nothing matches "zzz"/
    assert_select "a[href=?]", products_path, "See all products"
  end

  test "you may also like tops up a small collection with the shop's others" do
    get product_path("cat-tee")
    assert_select "h2", "You may also like"
    assert_select "a[href=?]", "/products/morning-mug", { minimum: 1 }, "the cats collection has only this tee"
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

  private
    # config/theme_settings.yml with these fields, for the block.
    def with_theme_file(fields)
      original = YAML.method(:safe_load_file)
      YAML.define_singleton_method(:safe_load_file) { |*| fields }
      yield
    ensure
      YAML.define_singleton_method(:safe_load_file, original)
    end

  test "personalized products wear a badge and lead the home page's Make it yours" do
    @platform.products_data.first["buyer_inputs"] = [ { "key" => "name", "label" => "Name", "required" => false, "max_length" => 12 } ]
    get root_path
    assert_select "h2", "Make it yours"
    assert_select "a[href='/products/cat-tee'] span", /Personalize/
    assert_select "li", "Personalize it before you buy"

    @platform.products_data.first["buyer_inputs"] = []
    get root_path
    assert_select "h2", text: "Make it yours", count: 0
    assert_select "li", text: "Personalize it before you buy", count: 0
  end

  test "a product in Make it yours isn't repeated in the newest products, when there are enough others" do
    tee = @platform.products_data.first
    tee["buyer_inputs"] = [ { "key" => "name", "label" => "Name", "required" => false, "max_length" => 12 } ]
    4.times { |index| @platform.products_data << tee.merge("slug" => "plain-tee-#{index}", "title" => "Plain Tee #{index}", "buyer_inputs" => []) }
    get root_path
    assert_select "a[href='/products/cat-tee']", 1
    assert_select "a[href='/products/plain-tee-0']", 1

    @platform.products_data << tee.merge("slug" => "plain-tee-4", "title" => "Plain Tee 4", "buyer_inputs" => [])
    get root_path
    assert_select "a[href^='/products/']", 5 # the tee in Make it yours, then whole rows of four: five would leave a gap
  end

  test "made to order never says free shipping for want of a flat rate: Printify's is known at checkout" do
    @platform.shop_data["shipping"] = @platform.shop_data["shipping"].merge("free_over_cents" => nil, "first_item_cents" => 0)
    get product_path("cat-tee")
    assert_select "li span", "Shipping calculated at checkout"
    assert_select "li span", text: "Free shipping", count: 0
  end
end
