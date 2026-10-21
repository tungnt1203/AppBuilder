require "test_helper"

class StorefrontApi::CatalogTest < ActionDispatch::IntegrationTest
  setup { @api_key = api_key_for }

  test "needs a shop's key, and a revoked one stops working" do
    get storefront_api_shop_path
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body.dig("error", "code")

    api :get, storefront_api_shop_path, key: "sk_shop_nope"
    assert_response :unauthorized

    ActsAsTenant.with_tenant(shops(:cats)) { ShopApiKey.sole.revoke! }
    api :get, storefront_api_shop_path
    assert_response :unauthorized
  end

  test "the shop: name, money, shipping, payments, policies" do
    shop = api(:get, storefront_api_shop_path)["shop"]
    assert_equal [ "Chubby Cat Tees", "USD", false ], shop.values_at("name", "currency", "preview")
    assert_equal({ "first_item_cents" => 500, "additional_item_cents" => 200, "free_over_cents" => 10000, "ships_to" => %w[ CA GB US ], "delivery_days" => nil, "delivery_dates" => nil },
      shop["shipping"].except("countries"))
    assert_equal %w[ CA GB US ], shop["shipping"]["countries"].pluck("code")
    assert_equal "California", shop["shipping"]["countries"].last.dig("regions", "CA")
    assert_nil shop["shipping"]["countries"].second["regions"]
    assert_equal false, shop["tax_at_payment"]
    assert_equal [ "manual" ], shop["payment_methods"]
    assert_equal "hello@example.com", shop.dig("contact", "email")

    assert api(:get, storefront_api_shop_path, key: api_key_for(kind: "preview"))["shop"]["preview"]
  end

  test "photos are at the Platform's public address, whatever address the storefront called" do
    original = Rails.configuration.x.platform_url
    Rails.configuration.x.platform_url = "https://platform.example"
    ActsAsTenant.with_tenant(shops(:cats)) do
      ThemeSetting.apply_schema!([ { "key" => "hero", "type" => "image" } ])
      ThemeSetting.current.images.attach(io: file_fixture("product.png").open, filename: "hero.png", content_type: "image/png", metadata: { "setting_key" => "hero" })
    end

    hero = api(:get, storefront_api_shop_path)["shop"]["theme_settings"]["hero"]
    assert hero.start_with?("https://platform.example/rails/active_storage/"), hero
  ensure
    Rails.configuration.x.platform_url = original
  end

  test "products on sale, newest first, with their prices; drafts aren't there" do
    body = api(:get, storefront_api_products_path)
    assert_equal %w[ morning-mug cat-mom-tee ], body["products"].pluck("slug")
    assert_equal [ 1, 24, 2, 1 ], body.values_at("page", "per_page", "total", "pages")
    tee = body["products"].last
    assert_equal [ 2400, "USD", 3000 ], tee["price"].values_at("min_cents", "currency", "compare_at_cents") # a variant is on sale
  end

  test "searches, filters by collection, sorts and pages" do
    assert_equal %w[ morning-mug ], api(:get, storefront_api_products_path(q: "MUG"))["products"].pluck("slug")
    assert_equal %w[ cat-mom-tee ], api(:get, storefront_api_products_path(collection: "cat-lovers"))["products"].pluck("slug")
    assert_equal %w[ cat-mom-tee morning-mug ], api(:get, storefront_api_products_path(sort: "title"))["products"].pluck("slug")
    body = api(:get, storefront_api_products_path(per_page: 1, page: 2))
    assert_equal [ [ "cat-mom-tee" ], 2, 2 ], [ body["products"].pluck("slug"), body["page"], body["pages"] ]

    api :get, storefront_api_products_path(collection: "nope")
    assert_response :not_found
  end

  test "a product with its options, variants and size guide" do
    product = api(:get, storefront_api_product_path("cat-mom-tee"))["product"]
    assert_equal [ "Cat Mom Tee", "Soft cotton tee with a hand-drawn cat.", "Size" ], product.values_at("title", "description", "size_option")
    assert_equal [ { "name" => "Color", "values" => %w[ Black White ] }, { "name" => "Size", "values" => %w[ S M ] } ], product["options"]
    variant = product["variants"].first
    assert_equal [ "Black / S", %w[ Black S ], "TEE-BLK-S", "TEE-BLK-S", 2400, true ], variant.values_at("title", "options", "sku", "catalog_id", "price_cents", "available")
    assert_equal false, product["made_to_order"]
    assert_equal [ { "slug" => "cat-lovers", "title" => "Cat Lovers" } ], product["collections"]

    api :get, storefront_api_product_path("draft-hoodie")
    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("error", "code")
  end

  test "another shop's key sees that shop only" do
    @api_key = api_key_for(shops(:dogs))
    assert_equal "Good Boy Hoodies", api(:get, storefront_api_shop_path)["shop"]["name"]
    assert_empty api(:get, storefront_api_products_path)["products"]
    api :get, storefront_api_product_path("cat-mom-tee")
    assert_response :not_found
  end

  test "collections with how many products on sale each has" do
    assert_equal [ { "slug" => "cat-lovers", "title" => "Cat Lovers", "product_count" => 1 } ], api(:get, storefront_api_collections_path)["collections"]
    assert_equal "Cat Lovers", api(:get, storefront_api_collection_path("cat-lovers"))["collection"]["title"]
  end

  test "a product in a list has its second photo, for a card that shows it on hover" do
    ActsAsTenant.with_tenant(shops(:cats)) do
      2.times { |i| products(:tee).images.attach(io: file_fixture("product.png").open, filename: "tee-#{i}.png", content_type: "image/png") }
    end

    tee = api(:get, storefront_api_products_path)["products"].find { |product| product["slug"] == "cat-mom-tee" }
    assert_equal products(:tee).images.second.id, tee.dig("second_image", "id")
    assert_nil api(:get, storefront_api_products_path)["products"].find { |product| product["slug"] == "morning-mug" }["second_image"]
  end

  test "a collection's photo is its first product on sale with one" do
    ActsAsTenant.with_tenant(shops(:cats)) do
      products(:hoodie).images.attach(io: file_fixture("product.png").open, filename: "hoodie.png", content_type: "image/png")
      collection_products(:cats_hoodie).update!(position: -1) # first, but a draft
      products(:tee).images.attach(io: file_fixture("product.png").open, filename: "tee.png", content_type: "image/png")
    end

    image = api(:get, storefront_api_collections_path)["collections"].first["image"]
    assert_equal [ products(:tee).images.first.id, "Cat Lovers" ], image.values_at("id", "alt")
    assert image["card"].include?("/rails/active_storage/")
    assert_equal image, api(:get, storefront_api_collection_path("cat-lovers"))["collection"]["image"]
  end

  test "policies the shop wrote" do
    ActsAsTenant.with_tenant(shops(:cats)) { Store.current.update!(refund_policy: "30 days, no questions.") }
    assert_equal [ { "id" => "refund", "title" => "Refund policy" } ], api(:get, storefront_api_shop_path)["shop"]["policies"]
    assert_equal "30 days, no questions.", api(:get, storefront_api_policy_path("refund"))["policy"]["body"]
    api :get, storefront_api_policy_path("terms")
    assert_response :not_found
  end

  test "a product's published reviews" do
    review = ActsAsTenant.with_tenant(shops(:cats)) { orders(:shipped).product_reviews.create!(product: products(:tee), rating: 5, body: "Love it", author_name: "Robin B.") }
    body = api(:get, storefront_api_product_reviews_path("cat-mom-tee"))
    assert_equal [ { "average" => 5.0, "count" => 1 }, [ "Love it" ] ], [ body["rating"], body["reviews"].pluck("body") ]

    ActsAsTenant.with_tenant(shops(:cats)) { review.hide! }
    assert_empty api(:get, storefront_api_product_reviews_path("cat-mom-tee"))["reviews"]
  end

  test "a ZIP code's city and state" do
    assert_equal({ "zip" => "78701", "country" => "US", "region" => "TX", "city" => "Austin" }, api(:get, storefront_api_zip_code_path("78701"))["zip_code"])
    api :get, storefront_api_zip_code_path("00000")
    assert_response :not_found
  end

  test "answers 304 when nothing changed since the storefront's copy" do
    api :get, storefront_api_product_path("cat-mom-tee")
    etag = response.headers["ETag"]
    assert etag
    api :get, storefront_api_product_path("cat-mom-tee"), headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end
end
