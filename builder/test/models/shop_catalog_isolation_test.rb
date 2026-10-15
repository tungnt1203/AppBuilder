require "test_helper"

# Two shops in one database: each sees only its own catalog, and may reuse what the other uses.
class ShopCatalogIsolationTest < ActiveSupport::TestCase
  test "each shop sees only its own products, collections, discounts and settings" do
    in_shop shops(:dogs)
    assert_empty Product.all
    assert_empty Collection.all
    assert_empty Discount.all
    assert_equal 600, Store.current.shipping_first_item_cents
    assert_nil Product.find_by(slug: "cat-mom-tee")

    in_shop shops(:cats)
    assert_equal %w[ cat-mom-tee draft-hoodie morning-mug ], Product.order(:slug).pluck(:slug)
    assert_equal 500, Store.current.shipping_first_item_cents
  end

  test "two shops may have the same slug, discount code and Printify product" do
    in_shop shops(:dogs)
    tee = Product.create!(title: "Cat Mom Tee", base_price: "20", printify_product_id: "pf-1")
    Discount.create!(code: "welcome10", kind: "percentage", percent_off: 15)

    assert_equal "cat-mom-tee", tee.slug
    assert_equal shops(:dogs), tee.shop
    assert_equal [ shops(:dogs) ], tee.variants.map(&:shop).uniq

    in_shop shops(:cats)
    assert_not Product.create(title: "Cat Mom Tee", base_price: "20", slug: "cat-mom-tee").persisted?, "unique within a shop"
    assert_equal 10, Discount.find_by!(code: "WELCOME10").percent_off
  end

  test "a shop's store settings carry its currency and code" do
    in_shop shops(:cats)
    assert_equal [ "USD", "cats01" ], [ Store.current.currency, Store.current.uid ]
  end

  test "each shop numbers its own orders from 1001, and never sees another shop's" do
    in_shop shops(:dogs)
    hoodie = Product.create!(title: "Good Boy Hoodie", base_price: "40", status: "active")
    cart = Cart.create!.tap { |each| each.add(hoodie.variants.first) }
    order = Checkout.new(cart:, email: "pat@example.com", shipping_name: "Pat", shipping_address1: "1 Main St",
      shipping_city: "Austin", shipping_region: "TX", shipping_postal_code: "78701", shipping_country: "US").place

    assert_equal 1001, order.number
    assert_equal [ order ], Order.all.to_a
    assert_equal [ shops(:dogs) ], order.line_items.map(&:shop).uniq
    assert_match "good-boy.", order.storefront_url

    in_shop shops(:cats)
    assert_not_includes Order.all, order
    assert Order.where(number: 1001).exists?, "the cats shop has its own 1001"
    assert_nil Order.find_by(token: order.token)
  end
end
