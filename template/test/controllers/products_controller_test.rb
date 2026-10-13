require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  test "lists active products for any visitor, even with no accounts" do
    User.delete_all
    get products_path

    assert_response :success
    assert_select "a[href=?]", product_path(products(:tee))
    assert_select "a[href=?]", product_path(products(:hoodie)), count: 0
  end

  test "search and sort" do
    get products_path(q: "mug", sort: "title")
    assert_select "a[href=?]", product_path(products(:mug))
    assert_select "a[href=?]", product_path(products(:tee)), count: 0
  end

  test "shows a product by its address, with its options and add to cart" do
    get product_path(products(:tee))

    assert_response :success
    assert_select "h1", "Cat Mom Tee"
    assert_select "input[type=radio][value=Black]"
    assert_select "input[name=variant_id][value=?]", variants(:tee_black_s).id.to_s
  end

  test "drafts aren't on the site" do
    get product_path(products(:hoodie))
    assert_response :not_found
  end

  test "home page shows the newest products and collections" do
    get root_path
    assert_select "a[href=?]", product_path(products(:mug))
    assert_select "a[href=?]", collection_path(collections(:cats))
  end

  test "collection page shows its active products" do
    get collection_path(collections(:cats))
    assert_response :success
    assert_select "a[href=?]", product_path(products(:tee))
    assert_select "a[href=?]", product_path(products(:hoodie)), count: 0
  end

  test "the product page says when it arrives, what shipping costs, and how sizes run" do
    stores(:main).update!(delivery_days_min: 5, delivery_days_max: 9)
    products(:tee).update!(size_guide: "Size | Chest\nS | 18\nM | 20")
    variants(:tee_black_s).update!(compare_at_price: "30")

    get product_path(products(:tee))
    assert_select "li", /Arrives/
    assert_select "li", /Free shipping over \$100/
    assert_select "button", "Size guide"
    assert_select "dialog#size-guide th", "Chest"
    assert_select "[data-variant-picker-target=saving]", /Save \d+%/
    assert_select "input[type=radio][value=Black] + span[style*='background-color']"
    assert_select "button[form=buy]", "Add to cart"
  end

  test "without delivery days or a size guide, it says printed to order and shows no guide" do
    get product_path(products(:tee))
    assert_select "li", /Printed just for you/
    assert_select "dialog#size-guide", count: 0
  end

  test "product pages describe the product for search engines" do
    get product_path(products(:tee))
    data = JSON.parse(css_select("script[type='application/ld+json']").first.text)
    assert_equal [ "Product", "Cat Mom Tee" ], data.values_at("@type", "name")
    assert_equal "TEE-BLK-S", data["offers"].first["sku"]
    assert_includes data["offers"].map { _1["availability"] }, "https://schema.org/OutOfStock"
  end
end
