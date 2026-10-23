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
    assert_select "[role=status]", /demo products. Only the builder.s preview shows them/
    assert_select "button", "Remove demo products"

    delete shop_admin_demo_products_path
    assert_equal 0, Product.count
  end

  test "the owner draws a print area per side and sees each side's sample print file in its shape" do
    tee = products(:tee)
    tee.images.attach(io: file_fixture("product.png").open, filename: "front.png", content_type: "image/png")
    tee.update!(buyer_inputs: [ { "label" => "Name", "preview" => { "x" => 0.3, "y" => 0.5, "w" => 0.4, "h" => 0.1, "font" => "Lora" } } ])
    get edit_shop_admin_product_path(tee)
    assert_select "#print-area", 0, "only Printify prints from a print area"

    tee.update!(printify_product_id: "pf-tee")
    get shop_admin_product_print_file_path(tee)
    assert_response :not_found

    patch shop_admin_product_path(tee), params: { product: { print_areas: { front: { x: "0.25", y: "0.2", w: "0.5", h: "0.25" }, back: { x: "", y: "", w: "", h: "" } } } }
    assert_equal({ "front" => { "x" => 0.25, "y" => 0.2, "w" => 0.5, "h" => 0.25 } }, tee.reload.print_areas)
    follow_redirect!
    assert_select "a[href=?]", shop_admin_product_print_file_path(tee, side: "front"), "See a sample print file"
    assert_select "input[name='product[print_areas][back][x]']"
    assert_select "select[name='product[buyer_inputs][][preview][side]']"

    get shop_admin_product_print_file_path(tee)
    assert_equal "image/png", response.media_type
    image = Vips::Image.new_from_buffer(response.body, "")
    assert_equal [ 1200, 750 ], [ image.width, image.height ], "the area's shape on the 40 × 50 photo"
  end

  test "a Printify product's print area can be found instead of drawn, or the owner is told to draw it" do
    printify = connect_fake_printify
    tee = products(:tee).tap { |product| product.update!(printify_product_id: "pf-tee") }
    tee.images.attach(io: file_fixture("product.png").open, filename: "front.png", content_type: "image/png")
    get edit_shop_admin_product_path(tee)
    assert_select "button[form=?]", "find_print_area_product_#{tee.id}", "Find it from Printify"
    assert_select "form#find_print_area_product_#{tee.id}[action=?]", shop_admin_product_print_area_path(tee)
    assert_select "form form", count: 0

    post shop_admin_product_print_area_path(tee)
    assert_redirected_to edit_shop_admin_product_path(tee, anchor: "print-area")
    assert_match "Draw the print area yourself", flash[:alert]
    assert_empty tee.reload.print_areas

    design = Vips::Image.black(400, 200, bands: 4).copy(interpretation: :srgb).draw_rect([ 0, 0, 0, 255 ], 100, 50, 200, 100, fill: true)
    printify.product_data["print_areas"].first["placeholders"] = [
      { "position" => "front", "images" => [ { "id" => "d", "type" => "image/png", "src" => "https://images.example/design.png", "x" => 0.5, "y" => 0.3, "scale" => 0.8 } ] }
    ]
    printify.define_singleton_method(:download) { |_url| StringIO.new(design.write_to_buffer(".png")) }
    photo = Vips::Image.black(600, 600).new_from_image([ 248, 248, 248 ]).copy(interpretation: :srgb).draw_rect([ 20, 20, 20 ], 252, 222, 96, 48, fill: true)
    tee.images.purge
    tee.images.attach(io: StringIO.new(photo.write_to_buffer(".jpg")), filename: "front.jpg", content_type: "image/jpeg")

    post shop_admin_product_print_area_path(tee)
    assert_match "Found the print area", flash[:notice]
    assert_in_delta 0.3, tee.reload.print_areas.dig("front", "x"), 0.01
    assert_equal [ 300, 400 ], tee.print_areas.dig("front", "pixels"), "Printify's print area in pixels"
  end

  test "a drawn print area learns its size in pixels from Printify, kept while the box moves" do
    connect_fake_printify
    tee = products(:tee).tap { |product| product.update!(printify_product_id: "pf-tee") }
    perform_enqueued_jobs(only: Product::PrintPixelsJob) do
      patch shop_admin_product_path(tee), params: { product: { print_areas: { front: { x: "0.25", y: "0.2", w: "0.5", h: "0.25" } } } }
    end
    in_shop
    assert_equal [ 300, 400 ], tee.reload.print_areas.dig("front", "pixels")

    assert_no_enqueued_jobs(only: Product::PrintPixelsJob) do
      patch shop_admin_product_path(tee), params: { product: { print_areas: { front: { x: "0.3", y: "0.2", w: "0.5", h: "0.25" } } } }
    end
    in_shop
    assert_equal [ 0.3, [ 300, 400 ] ], tee.reload.print_areas["front"].values_at("x", "pixels")

    assert_enqueued_with(job: Product::PrintPixelsJob) do
      patch shop_admin_product_path(tee), params: { product: { print_areas: { front: { x: "0.3", y: "0.2", w: "0.5", h: "0.25" }, back: { x: "0.3", y: "0.2", w: "0.5", h: "0.25" } } } }
    end
    in_shop
    assert_nil tee.reload.print_areas.dig("back", "pixels"), "the back's size is asked for"
  end

  test "print areas drawn before their size was known learn it in the daily sweep" do
    connect_fake_printify
    tee = products(:tee)
    tee.update_columns(printify_product_id: "pf-tee", print_areas: { "front" => { "x" => 0.3, "y" => 0.2, "w" => 0.5, "h" => 0.25, "pixels" => [ 10, 10 ] }, "back" => { "x" => 0.3, "y" => 0.2, "w" => 0.5, "h" => 0.25 } })
    Product::PrintPixelsJob.perform_now
    in_shop
    assert_equal [ [ 10, 10 ], [ 300, 400 ] ], tee.reload.print_areas.values_at("front", "back").pluck("pixels"), "only the ones without it"
  end

  test "a personalized Printify product says to draw its print area, and is badged in the list" do
    tee = products(:tee).tap { |product| product.update!(printify_product_id: "pf-tee", buyer_inputs: [ { "label" => "Name" } ]) }
    assert_includes tee.launch_problems, :no_print_area

    get edit_shop_admin_product_path(tee)
    assert_select "a[href='#print-area']", /Draw the print area/
    get shop_admin_products_path
    assert_select "span", "Personalized"

    tee.update!(print_areas: { "front" => { "x" => 0.2, "y" => 0.2, "w" => 0.5, "h" => 0.5 } })
    assert_not_includes tee.launch_problems, :no_print_area
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
