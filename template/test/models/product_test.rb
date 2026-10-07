require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "makes a variant for every combination of option values, at the base price" do
    product = Product.create!(title: "Bold Tee", base_price: "19.99", option1_name: "Color", option1_values_text: "Black, White",
      option2_name: "Size", option2_values_text: "S, M, L")

    assert_equal 6, product.variants.count
    assert_equal [ "Black", "S" ], product.variants.first.option_values
    assert product.variants.all? { |variant| variant.price_cents == 1999 }
  end

  test "a product without options has one variant" do
    product = Product.create!(title: "Sticker", base_price: "3")

    assert_equal 1, product.variants.count
    assert_nil product.variants.first.title
  end

  test "changing option values adds and removes variants and keeps the others' prices" do
    product = products(:tee)
    removed = variants(:tee_black_s).id
    product.update!(option2_values_text: "M, L")

    assert_equal [ %w[ Black M ], %w[ Black L ], %w[ White M ], %w[ White L ] ], product.variants.map(&:option_values)
    assert_equal 2600, product.variants.find { |variant| variant.option_values == %w[ White M ] }.price_cents
    assert_not Variant.exists?(removed)
    assert_equal 2400, product.variants.find { |variant| variant.option_values == %w[ Black L ] }.price_cents
  end

  test "orders keep their lines when a variant goes away" do
    products(:tee).update!(option2_values_text: "M")

    line = line_items(:pending_tee).reload
    assert_nil line.variant
    assert_equal "Black / S", line.variant_title
  end

  test "options must be filled in order and have values" do
    product = Product.new(title: "Odd", option2_name: "Size", option2_values_text: "S")
    assert_not product.valid?
    assert product.errors.added?(:base, :options_in_order)

    product = Product.new(title: "Odd", option1_name: "Size")
    assert_not product.valid?
    assert product.errors.include?(:option1_values)
  end

  test "too many combinations are refused" do
    values = (1..11).map(&:to_s).join(",")
    product = Product.new(title: "Huge", option1_name: "A", option1_values_text: values, option2_name: "B", option2_values_text: values)

    assert_not product.valid?
    assert product.errors.added?(:base, :too_many_variants)
  end

  test "slugs are unique, readable and stay when the title changes" do
    first = Product.create!(title: "Cat Mom Tee!")
    assert_equal "cat-mom-tee-2", first.slug # the fixture has cat-mom-tee

    first.update!(title: "Renamed")
    assert_equal "cat-mom-tee-2", first.slug
  end

  test "picks the variant for chosen options" do
    assert_equal variants(:tee_white_m), products(:tee).variant_for(%w[ White M ])
    assert_nil products(:tee).variant_for(%w[ White ])
  end

  test "price range covers the variants for sale" do
    assert_equal [ 2400, 2600 ], products(:tee).price_range
  end

  test "only active products are visible, and get a publish date" do
    assert_not_includes Product.visible, products(:hoodie)

    products(:hoodie).update!(status: "active")
    assert products(:hoodie).published_at
  end

  test "a price that isn't a number is an error, not zero" do
    product = Product.new(title: "Typo", base_price: "12,5x")
    assert_not product.valid?
    assert product.errors.include?(:base_price)
  end
end
