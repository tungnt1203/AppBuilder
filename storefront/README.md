# Storefront

The Rails 8 app every shop's storefront starts from (Platform v1). It has **no database**: the
shop, its catalog, carts, checkout and orders live on the Platform, and the storefront reads and
buys through the Storefront API with [`storefront_kit`](../blocks/storefront_kit). The owner runs
the shop in the Platform's admin; the storefront is only its look.

What it has:

- Home, catalog with search and collections, product page (photos by color, swatches, size
  guide, zoom, sticky buy bar on phones, reviews, what buyers type to be printed), cart with the
  free-shipping bar and discount codes, checkout (US ZIP fills city and state, Printify's real
  shipping quote), card payment with Stripe's Payment Element, the buyer's order page, reviews.
- The owner's pages, menus (`header`, `footer`), policies and contact form.
- Ad pixels (Meta, TikTok, Google) and `/feeds/products.xml` for catalog ads.
- `config/theme_settings.yml` and `config/forms.yml`, applied to the shop when it's published.

## Develop

It needs a running Platform and a shop key (the shop's admin, Settings › Storefront keys):

```sh
PLATFORM_URL=http://localhost:3000 SHOP_KEY=sk_preview_… STOREFRONT_MODE=preview bin/dev
bin/rails test     # against a Platform in memory (StorefrontKit::Testing::FakeApi)
bin/rubocop
```

`STOREFRONT_MODE=preview` reads the catalog fresh on every page; `live` caches it for 30 seconds.
A preview key's orders are test orders: never printed, paid in Stripe's test mode only.

## Run on ONCE

```sh
docker build -t localhost:5050/storefront:v1 . && docker push localhost:5050/storefront:v1
once deploy localhost:5050/storefront:v1 --host shop.localhost --auto-update=false
```

Configuration: `PLATFORM_URL`, `SHOP_KEY`, `SECRET_KEY_BASE`, `DISABLE_SSL`. The cache of the
Platform's answers is kept in `storage/` (mounted at `/rails/storage`), so the shop still shows
its catalog through a short outage of the Platform.
