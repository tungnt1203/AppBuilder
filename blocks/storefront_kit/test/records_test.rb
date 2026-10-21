require_relative "test_helper"

class RecordsTest < Minitest::Test
  def setup
    @api = StorefrontKit::Testing::FakeApi.new
  end

  def test_a_product_reads_its_fields_and_finds_variants_and_photos
    product = @api.product("cat-tee")
    assert_equal [ "Cat Tee", "cat-tee", 2400, 2600 ], [ product.title, product.to_param, product.min_price_cents, product.max_price_cents ]
    assert product.available?
    assert product.made_to_order?

    variant = product.variant_for(%w[ White S ])
    assert_equal 103, variant.id
    assert_equal "https://cdn.example/white-large.webp", product.image_for(variant).url(:large)
    assert_equal 20, product.variant_for(%w[ Black M ]).sale_percent
    assert product.options.first.color?
    assert_equal "#ffffff", product.options.first.color_for("White")
    assert_raises(NoMethodError) { product.not_a_field }
  end

  def test_a_cart_through_an_order
    cart = @api.create_cart
    cart = @api.add_to_cart(cart.token, variant_id: 101, quantity: 2)
    assert_equal [ 2, 4800 ], [ cart.item_count, cart.subtotal_cents ]
    assert_equal "Cat Tee", cart.items.first.product.title
    assert_raises(StorefrontKit::Unavailable) { @api.add_to_cart(cart.token, variant_id: 104) }

    quote = @api.quote(cart.token, shipping_country: "US", email: "")
    assert_equal({ "email" => "can't be blank" }, quote.problems)
    refute quote.shipping_known?

    fields = { email: "a@b.co", shipping_name: "Robin", shipping_address1: "5 Elm", shipping_city: "Austin", shipping_region: "TX",
      shipping_postal_code: "78701", shipping_country: "US", payment_method: "stripe" }
    order = @api.place_order(cart.token, idempotency_key: "k", **fields)
    assert_same order, @api.place_order(cart.token, idempotency_key: "k", **fields)
    assert order.pending?
    assert order.card?
    assert order.payment.required?
    assert_equal [ "Robin", "5 Elm", "Austin TX 78701", "US" ], order.shipping_address.lines
    assert_equal "pk_test_fake", @api.payment(order.token).publishable_key
    assert @api.cart(cart.token).empty?
  end

  def test_the_shop
    shop = @api.shop
    assert_equal "Tees for people who love a chubby cat", shop.theme_settings["hero_title"]
    assert shop.policy?("refund")
    refute shop.ad_tracking?
    assert_equal Date.today + 7, shop.shipping.delivery_dates.first
    assert_equal "Texas", shop.shipping.countries.last.regions["TX"]
  end

  def test_collections_with_and_without_a_photo
    cats, fresh = @api.collections
    assert_equal "https://cdn.example/cat-card.webp", cats.image.url
    assert_nil fresh.image
  end
end
