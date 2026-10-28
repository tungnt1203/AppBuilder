require "test_helper"

class BuyingTest < ActionDispatch::IntegrationTest
  ADDRESS = { email: "robin@example.com", phone: "", shipping_name: "Robin Buyer", shipping_address1: "5 Elm St", shipping_city: "Austin",
    shipping_region: "TX", shipping_postal_code: "78701", shipping_country: "US" }.freeze

  test "a buyer adds to the cart, changes it, uses a code and pays by bank transfer" do
    post cart_items_path, params: { variant_id: 102, quantity: 2 }
    assert_redirected_to cart_path
    follow_redirect!
    assert_select "#notice", /Cat Tee was added/
    assert_select "a", "Check out"
    assert_select "header span", "2"
    assert_select "[data-controller=quantity] input[name=quantity][value='2'][min='0']"
    assert_select "aside a[href='/checkout/new']", /Check out/

    item = @platform.carts.values.sole["lines"].sole
    patch cart_item_path(item["id"]), params: { quantity: 3 }
    post cart_discount_path, params: { code: "nope" }
    follow_redirect!
    assert_select "#alert", "That code doesn't exist"
    post cart_discount_path, params: { code: "save10" }
    follow_redirect!
    assert_select "span", "SAVE10"
    assert_select "p", /\$72\.00/

    get new_checkout_path
    assert_response :success
    assert_select "details summary", /Show order summary.*\$64\.80/m, "phones see what they buy and for how much (after the code) at the top"
    assert_select "select[name='checkout[shipping_country]'] option[value=US][selected]"
    assert_select "[data-region-names-value*=Texas]"

    post checkout_path, params: { idempotency_key: "k1", checkout: ADDRESS.merge(payment_method: "manual") }
    order = @platform.orders.values.sole
    assert_redirected_to order_path(order["token"], placed: 1)
    follow_redirect!
    assert_select "p", /Thank you, Robin Buyer/
    assert_select "h2", "How to pay"
    assert_select "p", /bank transfer to 123-456/
    assert_select "p", /Austin TX 78701\s*United States/, "the country by its name"
    assert_equal 7200 - 720, order["subtotal_cents"] - order["discount_cents"]
  end

  test "a card order goes to Stripe's Payment Element, and shows paid once Stripe took it" do
    post cart_items_path, params: { variant_id: 101 }
    post checkout_path, params: { idempotency_key: "k2", checkout: ADDRESS.merge(payment_method: "stripe") }
    token = @platform.orders.keys.sole
    assert_redirected_to order_payment_path(token)

    follow_redirect!
    assert_select "script[src='https://js.stripe.com/v3/']"
    assert_select "form[data-controller=stripe-payment][data-stripe-payment-client-secret-value=?]", "pi_fake_secret_#{token}"
    assert_select "form[data-stripe-payment-return-url-value=?]", order_url(token, placed: 1)
    billing = JSON.parse(css_select("form[data-controller=stripe-payment]").first["data-stripe-payment-billing-value"])
    assert_equal({ "name" => "Robin Buyer", "address" => { "country" => "US", "postal_code" => "78701" } }, billing, "Stripe's billing country is the shipping one, not the browser's")

    get order_path(token)
    assert_select "a[href=?]", order_payment_path(token)
    assert_select "time[data-controller=local-time][datetime=?]", @platform.orders[token]["placed_at"]

    @platform.pay!(token)
    get order_path(token, placed: 1)
    assert_select "p", /Thank you/
    get order_payment_path(token)
    assert_redirected_to order_path(token)
  end

  test "what the Platform finds wrong shows on the checkout form" do
    post cart_items_path, params: { variant_id: 101 }
    post checkout_path, params: { checkout: ADDRESS.merge(email: "nope", shipping_city: "", payment_method: "manual") }
    assert_response :unprocessable_entity
    assert_select "p.text-red-600", "Email is invalid"
    assert_select "p.text-red-600", "City can't be blank"
    assert_empty @platform.orders
  end

  test "checkout's totals follow the address, and an empty cart goes back to the cart" do
    get new_checkout_path
    assert_redirected_to cart_path

    post cart_items_path, params: { variant_id: 101 }
    get shipping_checkout_path(shipping_country: "US", shipping_postal_code: "78701", payment_method: "manual"), headers: { "Turbo-Frame" => "checkout_totals" }
    assert_select "turbo-frame#checkout_totals dd", "$4.75"
    assert_select "input[type=submit][value='Place order']"
  end

  test "a shop without payment instructions tells the buyer they come by email" do
    @platform.shop_data["payment_instructions"] = nil
    post cart_items_path, params: { variant_id: 102 }
    post checkout_path, params: { idempotency_key: "k2", checkout: ADDRESS.merge(payment_method: "manual") }
    follow_redirect!
    assert_select "h2", "How to pay"
    assert_select "p", /We'll email you how to pay/
  end

  test "what the buyer types to be printed goes with the line, and is asked for when it must be" do
    @platform.products_data.first["buyer_inputs"] = [ { "key" => "print_name", "label" => "Name on the shirt", "required" => true, "max_length" => 20 } ]
    get product_path("cat-tee")
    assert_select "input[name='properties[print_name]'][required][maxlength='20']"

    post cart_items_path, params: { variant_id: 101 }
    assert_redirected_to products_path
    follow_redirect!
    assert_select "#alert", "Name on the shirt can't be blank"

    post cart_items_path, params: { variant_id: 101, properties: { print_name: "Ada" } }
    follow_redirect!
    assert_select "p", /Name on the shirt: Ada/
  end

  test "a personalized product shows the buyer's text on its photo, and the line keeps it" do
    @platform.products_data.first["buyer_inputs"] = [ { "key" => "print_name", "label" => "Name on the shirt", "required" => false, "max_length" => 14,
      "preview" => { "x" => 0.3, "y" => 0.6, "w" => 0.4, "h" => 0.1, "images" => [], "font" => "Lora", "fonts" => [ "Lora", "Montserrat" ],
                     "color" => "#ffffff", "colors" => [ "#ffffff", "#f2c45a" ], "align" => "center", "uppercase" => true } } ]
    get product_path("cat-tee")
    assert_select "[data-controller~=personalize] img[data-personalize-target=photo]"
    assert_select "[data-personalize-target=layer][data-key=print_name][data-font=Lora][data-sample='Your text'] .uppercase"
    assert_select "input[name='properties[print_name]'][data-personalize-input=print_name]"
    assert_select "input[type=radio][name='properties[print_name_font]'][value=Montserrat]"
    assert_select "input[type=radio][name='properties[print_name_color]'][value='#f2c45a']"

    post cart_items_path, params: { variant_id: 101, properties: { print_name: "Ada", print_name_font: "Montserrat", print_name_color: "#f2c45a" } }
    get cart_path
    assert_select "[data-controller=personalize] [data-personalize-target=layer][data-text=Ada][data-font=Montserrat][data-color='#f2c45a']"
    assert_select "span[role=img][aria-label='#f2c45a'][style*='#f2c45a']", 1, "the color picked as its swatch, not its code"
  end

  test "a buyer's photo is sent as they pick it, and their line shows it framed on the product" do
    @platform.products_data.first["buyer_inputs"] = [ { "key" => "your_photo", "label" => "Your photo", "kind" => "photo", "required" => true,
      "preview" => { "x" => 0.25, "y" => 0.3, "w" => 0.5, "h" => 0.4, "images" => [] }, "print_pixels" => [ 3600, 3200 ] } ]
    get product_path("cat-tee")
    assert_select "[data-controller~=personalize][data-personalize-upload-url='/uploads']"
    assert_select "[data-personalize-photo-field=your_photo][data-print-pixels='[3600,3200]']", 1, "to tell the buyer when their photo is too small for it"
    assert_select "input[type=file][data-personalize-pick=your_photo][accept*='image/jpeg']"
    assert_select "input[type=hidden][name='properties[your_photo]'][required]"
    assert_select "input[type=hidden][name='properties[your_photo_crop]'][value='1,0.5,0.5']"
    assert_select "[data-personalize-target=layer][data-kind=photo][data-key=your_photo] img"

    post uploads_path, params: { photo: Rack::Test::UploadedFile.new(StringIO.new("not a photo"), "text/plain", original_filename: "notes.txt") }, as: :json
    assert_response :unprocessable_entity
    assert_match "JPEG, PNG or WebP", response.parsed_body["error"]

    post uploads_path, params: { photo: Rack::Test::UploadedFile.new(StringIO.new("\xFF\xD8\xFF"), "image/jpeg", original_filename: "family.jpg") }
    assert_response :created
    token = response.parsed_body["token"]
    assert_equal [ "upl_test1", 1200 ], [ token, response.parsed_body["width"] ]

    post cart_items_path, params: { variant_id: 101, properties: { your_photo: token, your_photo_crop: "1.8,0.4,0.6" } }
    get cart_path
    assert_select "p", /Your photo: Added/
    assert_select "[data-personalize-target=layer][data-kind=photo][data-crop='1.8,0.4,0.6'][data-photo$='upl_test1/large.webp']"
  end

  test "a picture and a background the buyer picks show on the product, and on their line" do
    moon = { "id" => 7, "label" => "Moon", "thumb" => "https://cdn.example/moon-thumb.webp", "large" => "https://cdn.example/moon.webp" }
    @platform.products_data.first["buyer_inputs"] = [
      { "key" => "background", "label" => "Background", "kind" => "color", "required" => false, "preview" => { "x" => 0, "y" => 0, "w" => 1, "h" => 1, "images" => [], "colors" => [ "#f4efe6", "#2d3a3a" ] } },
      { "key" => "sign", "label" => "Sign", "kind" => "choice", "required" => true, "options" => [ moon ], "preview" => { "x" => 0.4, "y" => 0.4, "w" => 0.2, "h" => 0.2, "images" => [] } }
    ]
    get product_path("cat-tee")
    assert_select "input[type=radio][name='properties[background]'][value='#f4efe6'][checked]"
    assert_select "input[type=radio][name='properties[sign]'][value='7'][required]"
    assert_select "img[src='https://cdn.example/moon-thumb.webp']"
    assert_select "[data-personalize-target=layer][data-kind=color][data-key=background]"
    assert_select "[data-personalize-target=layer][data-kind=choice][data-key=sign][data-options=?]", { "7" => moon["large"] }.to_json

    post cart_items_path, params: { variant_id: 101, properties: { background: "#2d3a3a", sign: "7" } }
    get cart_path
    assert_select "p", /Sign: Moon/
    assert_select "[data-personalize-target=layer][data-kind=color][data-color='#2d3a3a'] + [data-personalize-target=layer][data-kind=choice][data-picture='https://cdn.example/moon.webp']"
  end

  test "a curved monogram and a photo's looks are offered as the shop set them" do
    @platform.products_data.first["buyer_inputs"] = [
      { "key" => "initials", "label" => "Initials", "required" => false, "max_length" => 20,
        "preview" => { "x" => 0.3, "y" => 0.3, "w" => 0.4, "h" => 0.2, "images" => [], "font" => "Lora", "color" => "#111111", "fonts" => [], "colors" => [],
                       "align" => "center", "uppercase" => false, "curve" => 60, "style" => "monogram" } },
      { "key" => "photo", "label" => "Photo", "kind" => "photo", "required" => false,
        "preview" => { "x" => 0.3, "y" => 0.6, "w" => 0.3, "h" => 0.3, "images" => [], "filters" => %w[ original bw sepia ] } }
    ]
    get product_path("cat-tee")
    assert_select "input[name='properties[initials]'][maxlength='3']"
    assert_select "[data-personalize-target=layer][data-key=initials][data-curve='60'][data-style=monogram]"
    assert_select "input[type=radio][name='properties[photo_filter]']", 3
    assert_select "input[type=radio][name='properties[photo_filter]'][value=original][checked]"
  end

  test "a star map asks for a day, a time and a city, and draws the sky on the product" do
    @platform.products_data.first["buyer_inputs"] = [ { "key" => "night", "label" => "Our night", "kind" => "starmap", "required" => true,
      "preview" => { "x" => 0.3, "y" => 0.3, "w" => 0.4, "h" => 0.4, "images" => [], "sky" => "#0b1d3a", "ink" => "#ffffff", "lines" => true } } ]
    get product_path("cat-tee")
    assert_select "input[type=date][required][data-personalize-starmap-date=night]"
    assert_select "input[type=time][value='22:00'][data-personalize-starmap-time=night]"
    assert_select "select[name='properties[night_place]'] option[value=hanoi-vietnam]", "Hanoi, Vietnam"
    assert_select "input[type=hidden][name='properties[night]']"
    assert_select "[data-personalize-target=layer][data-kind=starmap][data-key=night][data-sky='#0b1d3a']"

    post cart_items_path, params: { variant_id: 101, properties: { night: "2020-02-14T21:30", night_place: "hanoi-vietnam" } }
    get cart_path
    assert_select "[data-personalize-target=layer][data-kind=starmap][data-when='2020-02-14T21:30'][data-place=hanoi-vietnam]"
  end

  test "something that can't be bought isn't added" do
    post cart_items_path, params: { variant_id: 104 }
    follow_redirect!
    assert_select "#alert", "That option isn't available any more."
  end

  test "ad pixels get the purchase once, with the catalog ids" do
    @platform.shop_data["pixels"]["meta"] = "123"
    post cart_items_path, params: { variant_id: 101 }
    post checkout_path, params: { checkout: ADDRESS.merge(payment_method: "manual") }
    assert_equal "123", @platform.shop.pixels.meta
    sent = @platform.requests.find { |name, _| name == :place_order }.last
    assert_equal "Robin Buyer", sent[:shipping_name]
    assert sent[:attribution].key?(:ip)

    follow_redirect!
    assert_select "meta[name=tracking][content*='123']"
    assert_match(/"name":"purchase"/, css_select("#tracking-events").text)
    get order_path(@platform.orders.keys.sole, placed: 1)
    assert_no_match(/"name":"purchase"/, css_select("#tracking-events").text)
  end

  test "a buyer reviews what they got once it shipped" do
    post cart_items_path, params: { variant_id: 101 }
    post checkout_path, params: { checkout: ADDRESS.merge(payment_method: "manual") }
    token = @platform.orders.keys.sole
    get new_order_review_path(token)
    assert_redirected_to order_path(token)

    @platform.ship!(token)
    get order_path(token)
    assert_select "a", "Track your package"
    get new_order_review_path(token)
    assert_select "input[name=author_name][value='Robin B.']"

    post order_review_path(token), params: { author_name: "Robin B.", reviews: { "cat-tee" => { rating: "", body: "" } } }
    assert_response :unprocessable_entity
    post order_review_path(token), params: { author_name: "Robin B.", reviews: { "cat-tee" => { rating: "5", body: "Love it" } } }
    assert_redirected_to order_path(token)
  end

  test "the contact form reaches the shop" do
    get contact_path
    assert_select "a[href='mailto:hello@chubbycat.example']"
    post form_submissions_path("contact"), params: { answers: { email: "a@b.co", message: "Hi" } }, headers: { "Referer" => contact_url }
    assert_redirected_to contact_url
    assert_equal [ { key: "contact", answers: { "email" => "a@b.co", "message" => "Hi" } } ], @platform.form_submissions
  end

  test "the ZIP code fills in the city and state" do
    get zip_code_path("78701")
    assert_equal({ "state" => "TX", "city" => "Austin" }, response.parsed_body)
    get zip_code_path("00000")
    assert_response :not_found
  end
end
