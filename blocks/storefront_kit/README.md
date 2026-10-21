# storefront_kit

What a shop's storefront uses to talk to the Platform's Storefront API
([docs/storefront-api.md](../../docs/storefront-api.md)): a client with the shop's key, typed
records (`Product`, `Variant`, `Cart`, `Order`…), a cache, and view helpers.

```ruby
storefront.products(collection: "cat-lovers", per_page: 4)  # a ListPage of Product
storefront.product("cat-mom-tee").variant_for(%w[ Black M ]) # a Variant
storefront.add_to_cart(current_cart!.token, variant_id: 12, properties: { print_name: "Ada" })
```

- `StorefrontKit.api`: the API, from `PLATFORM_URL`, `SHOP_KEY` and `STOREFRONT_MODE`.
- `Storefront` (controller concern): `current_shop`, `current_cart`, `current_cart!`, `storefront`.
- `StorefrontHelper` (views): `theme_setting`, `money`, `price_range`, `product_image`, `collection_image`,
  `shop_menu`, `products`, `collections`.
- Errors: `StorefrontKit::NotFound` (a 404), `Invalid` (with `fields`), `Unavailable`,
  `Unreachable` (the Platform is down; GETs fall back to what's cached).
- Tests: `require "storefront_kit/testing"` and `StorefrontKit.api = StorefrontKit::Testing::FakeApi.new`.

Its own tests: `cd storefront && bundle exec ruby -Ivendor/blocks/storefront_kit/lib -e 'Dir["vendor/blocks/storefront_kit/test/*_test.rb"].each { |f| require "./#{f}" }'`.
