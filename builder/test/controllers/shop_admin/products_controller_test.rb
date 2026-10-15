require "test_helper"

class ShopAdmin::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup { in_shop_admin }
  setup { sign_in_as users(:cats_staff) }

  test "needs a staff sign in" do
    sign_out
    get shop_admin_products_path
    assert_redirected_to new_session_path(shop_id: nil)
  end

  test "an admin adds demo products to an empty shop, sees they're there, and removes them" do
    sign_in_as users(:member)
    Product.destroy_all

    get shop_admin_products_path
    assert_select "button", "Add demo products"

    post shop_admin_demo_products_path
    assert_redirected_to shop_admin_products_path
    follow_redirect!
    assert_select "[role=status]", /demo products, and visitors see them/
    assert_select "button", "Remove demo products"

    delete shop_admin_demo_products_path
    assert_equal 0, Product.count
  end

  test "staff can't add or remove demo products" do
    post shop_admin_demo_products_path
    assert_not DemoCatalog.present?
  end

  test "lists, filters and searches products" do
    get shop_admin_products_path
    assert_select "a[href=?]", edit_shop_admin_product_path(products(:hoodie))

    get shop_admin_products_path(status: "draft")
    assert_select "a[href=?]", edit_shop_admin_product_path(products(:tee)), count: 0

    get shop_admin_products_path(q: "mug")
    assert_select "a[href=?]", edit_shop_admin_product_path(products(:mug))
  end

  test "adds a product with options and photos" do
    assert_difference -> { Product.count } do
      post shop_admin_products_path, params: { product: {
        title: "Night Owl Tee", status: "active", base_price: "21.50",
        option1_name: "Size", option1_values_text: "S, M, L",
        images: [ fixture_file_upload("product.png", "image/png"), fixture_file_upload("notes.txt", "text/plain") ]
      } }
    end

    product = Product.last
    assert_redirected_to edit_shop_admin_product_path(product)
    assert_equal 3, product.variants.count
    assert_equal [ 2150 ], product.variants.map(&:price_cents).uniq
    assert_equal 1, product.images.count
  end

  test "edits variants' prices and availability" do
    variant = variants(:tee_black_s)
    patch shop_admin_product_path(products(:tee)), params: { product: {
      title: "Cat Mom Tee",
      variants_attributes: { "0" => { id: variant.id, price: "27", compare_at_price: "32", sku: "NEW", available: "0" } }
    } }

    assert_redirected_to edit_shop_admin_product_path(products(:tee))
    variant.reload
    assert_equal [ 2700, 3200, "NEW", false ], [ variant.price_cents, variant.compare_at_price_cents, variant.sku, variant.available ]
  end

  test "new photos are added to the ones there" do
    products(:mug).images.attach(fixture_file_upload("product.png", "image/png"))
    patch shop_admin_product_path(products(:mug)), params: { product: { title: "Morning Mug", images: [ fixture_file_upload("product.png", "image/png") ] } }

    assert_equal 2, products(:mug).reload.images.count
  end

  test "removes a photo" do
    products(:mug).images.attach(fixture_file_upload("product.png", "image/png"))
    image = products(:mug).images.first

    delete shop_admin_product_image_path(products(:mug), image)
    perform_enqueued_jobs
    assert_equal 0, products(:mug).reload.images.count
  end

  test "invalid details show the form again" do
    post shop_admin_products_path, params: { product: { title: "" } }
    assert_response :unprocessable_entity
  end

  test "deleting keeps past orders' lines" do
    delete shop_admin_product_path(products(:tee))

    assert_redirected_to shop_admin_products_path
    assert_not Product.exists?(products(:tee).id)
    assert_equal "Cat Mom Tee", line_items(:pending_tee).reload.product_title
  end

  test "edit page shows the variants" do
    get edit_shop_admin_product_path(products(:tee))
    assert_response :success
    assert_select "input[name*='variants_attributes']", minimum: 4
  end

  test "sets a size guide and which color each photo shows" do
    products(:tee).images.attach(fixture_file_upload("product.png", "image/png"))
    image = products(:tee).images.first

    get edit_shop_admin_product_path(products(:tee))
    assert_select "select[name=?]", "product[photo_options][#{image.id}]"

    patch shop_admin_product_path(products(:tee)), params: { product: { title: "Cat Mom Tee", size_guide: "Size | Chest", photo_options: { image.id => "White" } } }
    assert_equal "Size | Chest", products(:tee).reload.size_guide
    assert_equal({ "White" => image.id }, products(:tee).option_images)
  end
end
