require "test_helper"

class StorefrontApi::ExtensionsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { @api_key = api_key_for }

  test "theme settings, custom fields and buyer inputs" do
    ActsAsTenant.with_tenant(shops(:cats)) do
      ThemeSetting.apply_schema!([
        { "key" => "hero_title", "type" => "text", "label" => "Hero", "default" => "Hello" },
        { "key" => "accent_color", "type" => "color", "default" => "#e8743b" }
      ])
      ThemeSetting.current.update!(values: { "hero_title" => "Chubby cats" })
      CustomFieldDefinition.create!(key: "material", label: "Material", field_type: "text")
      products(:tee).update!(custom_fields: { "material" => "Cotton" }, buyer_inputs: [ { "key" => "print_name", "label" => "Name on the shirt", "required" => true, "max_length" => 20 } ])
    end

    shop = api(:get, storefront_api_shop_path)["shop"]
    assert_equal({ "hero_title" => "Chubby cats" }, shop["theme_settings"]) # the storefront has the defaults

    product = api(:get, storefront_api_product_path("cat-mom-tee"))["product"]
    assert_equal [ { "key" => "material", "label" => "Material", "type" => "text", "value" => "Cotton" } ], product["custom_fields"]
    assert_equal "print_name", product["buyer_inputs"].sole["key"]

    token = api(:post, storefront_api_carts_path)["cart"]["token"]
    api :post, storefront_api_cart_items_path(token), params: { variant_id: variants(:tee_black_s).id }
    assert_response :unprocessable_entity
    assert_equal "can't be blank", response.parsed_body.dig("error", "fields", "print_name")
    assert_equal "Name on the shirt can't be blank", response.parsed_body.dig("error", "message"), "worded with the field's label, for the buyer"

    cart = api(:post, storefront_api_cart_items_path(token), params: { variant_id: variants(:tee_black_s).id, properties: { print_name: "Ada" } })["cart"]
    assert_equal [ { "key" => "print_name", "label" => "Name on the shirt", "value" => "Ada" } ], cart["items"].sole["properties"]
    api :post, storefront_api_cart_items_path(token), params: { variant_id: variants(:tee_black_s).id, properties: { print_name: "Bea" } }
    assert_equal 2, api(:get, storefront_api_cart_path(token))["cart"]["items"].size
  end

  test "a personalized line comes with the buyer's text as it shows on its photo" do
    photo = ActsAsTenant.with_tenant(shops(:cats)) do
      tee = products(:tee)
      tee.images.attach(io: file_fixture("product.png").open, filename: "front.png", content_type: "image/png")
      tee.update!(buyer_inputs: [ { "label" => "Name", "preview" => { "x" => 0.3, "y" => 0.6, "w" => 0.4, "h" => 0.1, "font" => "Lora",
        "fonts" => [ "Lora", "Montserrat" ], "color" => "#ffffff", "colors" => "#ffffff, #f2c45a" } } ])
      tee.images.attachments.sole
    end

    assert api(:get, storefront_api_products_path)["products"].find { |product| product["slug"] == "cat-mom-tee" }["personalized"]
    preview = api(:get, storefront_api_product_path("cat-mom-tee"))["product"]["buyer_inputs"].sole["preview"]
    assert_equal [ [ "Lora", "Montserrat" ], [ "#ffffff", "#f2c45a" ] ], preview.values_at("fonts", "colors")

    token = api(:post, storefront_api_carts_path)["cart"]["token"]
    line = api(:post, storefront_api_cart_items_path(token), params: { variant_id: variants(:tee_black_s).id, properties: { name: "Ada", name_font: "Montserrat", name_color: "#000000" } })["cart"]["items"].sole
    assert_equal [ "Name", "Name font" ], line["properties"].pluck("label")
    assert_equal [ { "x" => 0.3, "y" => 0.6, "w" => 0.4, "h" => 0.1, "align" => "center", "uppercase" => false, "curve" => 0, "style" => "plain", "kind" => "text", "text" => "Ada", "font" => "Montserrat", "color" => "#ffffff" } ], line["preview"]
    assert_equal photo.id, line.dig("product", "image", "id")
  end

  test "a buyer's photo is kept, and its line shows it framed on the product photo" do
    ActsAsTenant.with_tenant(shops(:cats)) do
      tee = products(:tee)
      tee.images.attach(io: file_fixture("product.png").open, filename: "front.png", content_type: "image/png")
      tee.update!(buyer_inputs: [ { "label" => "Your photo", "kind" => "photo", "required" => "1", "preview" => { "x" => 0.25, "y" => 0.3, "w" => 0.5, "h" => 0.4 } } ],
        print_areas: { "front" => { "x" => 0.25, "y" => 0.2, "w" => 0.5, "h" => 0.6, "pixels" => [ 3600, 4800 ] } })
    end
    field = api(:get, storefront_api_product_path("cat-mom-tee"))["product"]["buyer_inputs"].sole
    assert_equal [ 3600, 3200 ], field["print_pixels"], "the box's share of the print area"

    api :post, storefront_api_uploads_path, params: nil, headers: { "Content-Type" => nil }
    assert_response :bad_request
    post storefront_api_uploads_path, params: { photo: fixture_file_upload("notes.txt", "text/plain") }, headers: { "Authorization" => "Bearer #{@api_key}" }
    assert_response :unprocessable_entity
    assert_match "JPEG, PNG or WebP", response.parsed_body.dig("error", "fields", "photo")

    post storefront_api_uploads_path, params: { photo: fixture_file_upload("product.png", "image/png") }, headers: { "Authorization" => "Bearer #{@api_key}" }
    assert_response :created
    upload = response.parsed_body["upload"]
    assert_match(/\Aupl_/, upload["token"])
    assert upload["width"].positive?
    assert upload["large"].present?

    token = api(:post, storefront_api_carts_path)["cart"]["token"]
    api :post, storefront_api_cart_items_path(token), params: { variant_id: variants(:tee_black_s).id, properties: { your_photo: "upl_nope" } }
    assert_equal "isn't a photo you added", response.parsed_body.dig("error", "fields", "your_photo")

    line = api(:post, storefront_api_cart_items_path(token), params: { variant_id: variants(:tee_black_s).id, properties: { your_photo: upload["token"], your_photo_crop: "1.5,0.4,9" } })["cart"]["items"].sole
    assert_equal [ { "key" => "your_photo", "label" => "Your photo", "value" => "Added", "thumb" => upload["thumb"], "large" => upload["large"] } ], line["properties"]
    assert_equal [ { "x" => 0.25, "y" => 0.3, "w" => 0.5, "h" => 0.4, "kind" => "photo", "crop" => [ 1.5, 0.4, 1.0 ], "filter" => "original", "photo" => upload["large"] } ], line["preview"]
  end

  test "a choice field lists its pictures, and its line names and shows the one picked" do
    art = ActsAsTenant.with_tenant(shops(:cats)) do
      tee = products(:tee)
      tee.images.attach(io: file_fixture("product.png").open, filename: "front.png", content_type: "image/png")
      tee.artwork.attach(io: file_fixture("product.png").open, filename: "golden_retriever.png", content_type: "image/png")
      art = tee.artwork.attachments.sole
      tee.update!(buyer_inputs: [ { "label" => "Breed", "kind" => "choice", "options" => [ art.id, 999 ], "preview" => { "x" => 0.3, "y" => 0.3, "w" => 0.4, "h" => 0.4 } } ])
      art
    end

    options = api(:get, storefront_api_product_path("cat-mom-tee"))["product"]["buyer_inputs"].sole["options"]
    assert_equal [ [ art.id, "Golden retriever" ] ], options.map { |option| option.values_at("id", "label") }
    assert options.sole["large"].present?

    token = api(:post, storefront_api_carts_path)["cart"]["token"]
    line = api(:post, storefront_api_cart_items_path(token), params: { variant_id: variants(:tee_black_s).id, properties: { breed: art.id.to_s } })["cart"]["items"].sole
    assert_equal [ "Breed", "Golden retriever" ], line["properties"].sole.values_at("label", "value")
    assert_equal [ "choice", options.sole["large"] ], line["preview"].sole.values_at("kind", "picture")
  end

  test "a star map's line names its city, and shows the sky on its photo" do
    ActsAsTenant.with_tenant(shops(:cats)) do
      tee = products(:tee)
      tee.images.attach(io: file_fixture("product.png").open, filename: "front.png", content_type: "image/png")
      tee.update!(buyer_inputs: [ { "label" => "Our night", "kind" => "starmap", "preview" => { "x" => 0.3, "y" => 0.3, "w" => 0.4, "h" => 0.4 } } ])
    end

    token = api(:post, storefront_api_carts_path)["cart"]["token"]
    line = api(:post, storefront_api_cart_items_path(token), params: { variant_id: variants(:tee_black_s).id, properties: { our_night: "2020-02-14T21:30", our_night_place: "hanoi-vietnam" } })["cart"]["items"].sole
    assert_equal [ [ "Our night", "February 14, 2020, 9:30 PM" ], [ "Our night city", "Hanoi, Vietnam" ] ], line["properties"].map { |entry| entry.values_at("label", "value") }
    assert_equal [ "starmap", "2020-02-14T21:30", "hanoi-vietnam", "#0b1d3a" ], line["preview"].sole.values_at("kind", "when", "place", "sky")
  end

  test "pages, menus and a form message" do
    ActsAsTenant.with_tenant(shops(:cats)) do
      Page.create!(title: "Questions", body: "We print tees.", faqs: [ { "question" => "How long?", "answer" => "A week." } ], published: true)
      Page.create!(title: "Secret", body: "Not yet", published: false)
      Menu.create!(key: "header", title: "Header", items: [ { "label" => "Questions", "url" => "/pages/questions" } ])
      Form.declare!("contact", title: "Contact", fields: [ { "key" => "email", "label" => "Email", "type" => "email", "required" => true }, { "key" => "message", "label" => "Message", "type" => "textarea", "required" => true } ])
    end

    page = api(:get, storefront_api_page_path("questions"))["page"]
    assert_equal [ "text", "faq" ], page["blocks"].pluck("type")
    api :get, storefront_api_page_path("secret")
    assert_response :not_found
    assert_equal "/pages/questions", api(:get, storefront_api_menu_path("header"))["menu"]["items"].sole["url"]

    assert_enqueued_emails 1 do
      api :post, storefront_api_form_submissions_path("contact"), params: { answers: { email: "a@b.co", message: "Hi" } }, headers: { "Idempotency-Key" => "form-1" }
      assert_response :created
    end
    assert_no_enqueued_emails do
      api :post, storefront_api_form_submissions_path("contact"), params: { answers: { email: "a@b.co", message: "Hi" } }, headers: { "Idempotency-Key" => "form-1" }
      assert_response :created
      assert_equal "true", response.headers["Idempotent-Replayed"]
    end
    assert_equal 1, ActsAsTenant.with_tenant(shops(:cats)) { FormSubmission.count }

    @api_key = api_key_for(shops(:dogs))
    api :get, storefront_api_page_path("questions")
    assert_response :not_found
  end

  test "a form takes a few messages a minute" do
    ActsAsTenant.with_tenant(shops(:cats)) { Form.declare!("contact", title: "Contact", fields: [ { "key" => "email", "label" => "Email", "type" => "email" } ]) }
    original = Rails.cache.method(:increment)
    Rails.cache.define_singleton_method(:increment) { |name, *rest, **options| name.include?(":form:") ? 11 : original.call(name, *rest, **options) }

    assert_no_enqueued_emails do
      api :post, storefront_api_form_submissions_path("contact"), params: { answers: { email: "a@b.co" } }
    end
    assert_response :too_many_requests
    assert_equal "rate_limited", response.parsed_body.dig("error", "code")
  ensure
    Rails.cache.define_singleton_method(:increment, original)
  end
end
