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
    assert_equal({ "hero_title" => "Chubby cats", "accent_color" => "#e8743b" }, shop["theme_settings"])

    product = api(:get, storefront_api_product_path("cat-mom-tee"))["product"]
    assert_equal [ { "key" => "material", "label" => "Material", "type" => "text", "value" => "Cotton" } ], product["custom_fields"]
    assert_equal "print_name", product["buyer_inputs"].sole["key"]

    token = api(:post, storefront_api_carts_path)["cart"]["token"]
    api :post, storefront_api_cart_items_path(token), params: { variant_id: variants(:tee_black_s).id }
    assert_response :unprocessable_entity
    assert_equal "can't be blank", response.parsed_body.dig("error", "fields", "print_name")

    cart = api(:post, storefront_api_cart_items_path(token), params: { variant_id: variants(:tee_black_s).id, properties: { print_name: "Ada" } })["cart"]
    assert_equal [ { "key" => "print_name", "label" => "Name on the shirt", "value" => "Ada" } ], cart["items"].sole["properties"]
    api :post, storefront_api_cart_items_path(token), params: { variant_id: variants(:tee_black_s).id, properties: { print_name: "Bea" } }
    assert_equal 2, api(:get, storefront_api_cart_path(token))["cart"]["items"].size
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
