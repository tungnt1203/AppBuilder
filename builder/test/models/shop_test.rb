require "test_helper"

class ShopTest < ActiveSupport::TestCase
  test "opens with its owner, a code of its own and a valid address" do
    shop = Shop.open!(owner: users(:member), name: "Tabby Tees", subdomain: " Tabby-Tees ")

    assert_equal "tabby-tees", shop.subdomain
    assert_match(/\A[a-z0-9]{6}\z/, shop.uid)
    assert_equal "owner", shop.role_of(users(:member))
    assert_includes users(:member).shops, shop

    assert_not Shop.new(name: "X", subdomain: "admin").valid?, "reserved"
    assert_not Shop.new(name: "X", subdomain: "-cats").valid?
    assert_not Shop.new(name: "X", subdomain: "cats2", time_zone: "Mars/Base").valid?
  end

  test "a storefront key is shown once, kept as a digest, and finds its shop" do
    shop = Shop.open!(owner: users(:member), name: "Cats", subdomain: "more-cats")
    key = ActsAsTenant.with_tenant(shop) { shop.api_keys.create! }

    assert key.token.start_with?("sk_shop_")
    assert_not_includes ShopApiKey.connection.select_values("SELECT token_digest FROM shop_api_keys"), key.token
    assert_equal key, ShopApiKey.authenticate(key.token)
    assert ShopApiKey.authenticate(key.token).last_used_at

    ActsAsTenant.with_tenant(shop) { key.revoke! }
    assert_nil ShopApiKey.authenticate(key.token)
    assert_nil ShopApiKey.authenticate("sk_shop_wrong")
  end

  test "a shop's data is only read inside that shop" do
    cats = Shop.open!(owner: users(:member), name: "Cats", subdomain: "more-cats")
    dogs = Shop.open!(owner: users(:member), name: "Dogs", subdomain: "more-dogs")
    cats_key = ActsAsTenant.with_tenant(cats) { cats.api_keys.create! }
    ActsAsTenant.with_tenant(dogs) { dogs.api_keys.create!(kind: "preview") }

    ActsAsTenant.with_tenant(cats) do
      assert_equal [ cats_key ], ShopApiKey.all.to_a
      assert_raises(ActiveRecord::RecordNotFound) { ShopApiKey.find(ActsAsTenant.without_tenant { ShopApiKey.find_by!(shop: dogs).id }) }
    end
    assert_raises(ActsAsTenant::Errors::NoTenantSet) { ShopApiKey.count }
  end

  test "a shop that never took an order is purged with its data and photos; one with orders stays" do
    shop = Shop.open!(owner: users(:owner), name: "Test Shop", subdomain: "test-shop")
    product = ActsAsTenant.with_tenant(shop) do
      Product.create!(title: "Tee", status: "active").tap do |tee|
        tee.variants.create!(option1: "S", price_cents: 2000)
        tee.images.attach(io: file_fixture("product.png").open, filename: "tee.png", content_type: "image/png")
      end
    end
    ActsAsTenant.with_tenant(shop) { shop.api_keys.create! }

    assert_difference -> { ActiveStorage::Attachment.count } => -1, -> { ActsAsTenant.without_tenant { Variant.count } } => -1 do
      shop.purge!
    end
    assert_not Shop.exists?(shop.id)
    assert_not ActsAsTenant.without_tenant { Product.exists?(product.id) }

    assert_raises(ActiveRecord::RecordNotDestroyed) { shops(:cats).purge! }
    assert Shop.exists?(shops(:cats).id)
  end
end
