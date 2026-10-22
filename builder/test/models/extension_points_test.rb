require "test_helper"

class ExtensionPointsTest < ActiveSupport::TestCase
  setup { in_shop }

  test "theme settings keep a value when the field stays, and drop it when the type changes" do
    ThemeSetting.apply_schema!([
      { "key" => "hero_title", "type" => "text", "label" => "Hero", "default" => "Hi" },
      { "key" => "show_banner", "type" => "boolean", "default" => true }
    ], version: "1")
    ThemeSetting.current.update!(values: { "hero_title" => "Cats" })

    ThemeSetting.apply_schema!([
      { "key" => "hero_title", "type" => "text", "label" => "Hero title", "default" => "Hello" },
      { "key" => "accent_color", "type" => "color", "default" => "#e8743b" }
    ], version: "2")
    setting = ThemeSetting.current
    assert_equal [ "Cats", "2" ], [ setting.values["hero_title"], setting.schema_version ]
    assert_equal({ "hero_title" => "Cats", "accent_color" => "#e8743b" }, setting.resolved)
    assert_equal false, setting.resolved.key?("show_banner")

    ThemeSetting.apply_schema!([ { "key" => "hero_title", "type" => "color", "default" => "#112233" } ])
    assert_nil ThemeSetting.current.values["hero_title"]
    assert_equal "#112233", ThemeSetting.current.resolved["hero_title"]
  end

  test "a theme value has to match its type" do
    ThemeSetting.apply_schema!([ { "key" => "accent_color", "type" => "color", "label" => "Accent", "default" => "#e8743b" } ])
    setting = ThemeSetting.current
    assert_not setting.update_values({ "accent_color" => "orange" })
    assert setting.update_values({ "accent_color" => "" })
    assert_equal "#e8743b", setting.resolved["accent_color"]
  end

  test "buyer inputs are their own cart lines, and have to fit" do
    product = products(:tee)
    product.update!(buyer_inputs: [ { "key" => "print_name", "label" => "Name on the shirt", "required" => "1", "max_length" => "20" } ])
    assert_equal [ { "key" => "print_name", "label" => "Name on the shirt", "kind" => "text", "required" => true, "max_length" => 20 } ], product.buyer_inputs

    variant = variants(:tee_black_s)
    _properties, problems = product.buyer_properties({})
    assert_equal "can't be blank", problems["print_name"]
    _properties, problems = product.buyer_properties({ "print_name" => "a" * 21 })
    assert_match "too long", problems["print_name"]

    cart = Cart.create!
    properties, = product.buyer_properties({ "print_name" => "Ada" })
    cart.add(variant, 1, properties:)
    cart.add(variant, 1, properties:)
    other, = product.buyer_properties({ "print_name" => "Bea" })
    cart.add(variant, 1, properties: other)
    assert_equal [ 2, 1 ], cart.items.order(:id).map(&:quantity)
  end

  test "a page needs words, a menu only safe links, a form its fields" do
    assert_not Page.new(title: "About").valid?

    page = Page.create!(title: "Questions", faqs: [ { "question" => "How long?", "answer" => "A week." } ], published: true)
    assert_equal "faq", page.blocks.sole["type"]

    assert_not Menu.new(key: "header", title: "Header", items: [ { "label" => "Shop", "url" => "javascript:alert(1)" } ]).valid?
    menu = Menu.create!(key: "header", title: "Header", items: [ { "label" => "About", "url" => "/pages/about" }, { "label" => "", "url" => "" } ])
    assert_equal [ { "label" => "About", "url" => "/pages/about" } ], menu.items

    form = Form.declare!("contact", title: "Contact", fields: [ { "label" => "Email", "type" => "email", "required" => true } ])
    assert_equal "email", form.fields.sole["key"]
    submission = form.submissions.build
    assert_not submission.submit({ "email" => "nope" })
    assert submission.submit({ "email" => "a@b.co" })
    assert_equal [ "Email: a@b.co" ], submission.lines
  end
end
