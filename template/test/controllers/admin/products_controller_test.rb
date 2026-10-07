require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:staff) }

  test "needs a staff sign in" do
    sign_out
    get admin_products_path
    assert_redirected_to new_admin_session_path
  end

  test "lists, filters and searches products" do
    get admin_products_path
    assert_select "a[href=?]", edit_admin_product_path(products(:hoodie))

    get admin_products_path(status: "draft")
    assert_select "a[href=?]", edit_admin_product_path(products(:tee)), count: 0

    get admin_products_path(q: "mug")
    assert_select "a[href=?]", edit_admin_product_path(products(:mug))
  end

  test "adds a product with options and photos" do
    assert_difference -> { Product.count } do
      post admin_products_path, params: { product: {
        title: "Night Owl Tee", status: "active", base_price: "21.50",
        option1_name: "Size", option1_values_text: "S, M, L",
        images: [ fixture_file_upload("product.png", "image/png"), fixture_file_upload("notes.txt", "text/plain") ]
      } }
    end

    product = Product.last
    assert_redirected_to edit_admin_product_path(product)
    assert_equal 3, product.variants.count
    assert_equal [ 2150 ], product.variants.map(&:price_cents).uniq
    assert_equal 1, product.images.count
  end

  test "edits variants' prices and availability" do
    variant = variants(:tee_black_s)
    patch admin_product_path(products(:tee)), params: { product: {
      title: "Cat Mom Tee",
      variants_attributes: { "0" => { id: variant.id, price: "27", compare_at_price: "32", sku: "NEW", available: "0" } }
    } }

    assert_redirected_to edit_admin_product_path(products(:tee))
    variant.reload
    assert_equal [ 2700, 3200, "NEW", false ], [ variant.price_cents, variant.compare_at_price_cents, variant.sku, variant.available ]
  end

  test "new photos are added to the ones there" do
    products(:mug).images.attach(fixture_file_upload("product.png", "image/png"))
    patch admin_product_path(products(:mug)), params: { product: { title: "Morning Mug", images: [ fixture_file_upload("product.png", "image/png") ] } }

    assert_equal 2, products(:mug).reload.images.count
  end

  test "removes a photo" do
    products(:mug).images.attach(fixture_file_upload("product.png", "image/png"))
    image = products(:mug).images.first

    delete admin_product_image_path(products(:mug), image)
    perform_enqueued_jobs
    assert_equal 0, products(:mug).reload.images.count
  end

  test "invalid details show the form again" do
    post admin_products_path, params: { product: { title: "" } }
    assert_response :unprocessable_entity
  end

  test "deleting keeps past orders' lines" do
    delete admin_product_path(products(:tee))

    assert_redirected_to admin_products_path
    assert_not Product.exists?(products(:tee).id)
    assert_equal "Cat Mom Tee", line_items(:pending_tee).reload.product_title
  end

  test "edit page shows the variants" do
    get edit_admin_product_path(products(:tee))
    assert_response :success
    assert_select "input[name*='variants_attributes']", minimum: 4
  end
end
