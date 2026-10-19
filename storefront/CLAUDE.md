# CLAUDE.md

This is a shop's **storefront**: the website buyers see. The shop itself (its products, prices,
stock, carts, orders, payments, Printify, emails, settings) lives on the **Platform**, and the
owner runs it in the Platform's admin. This app has **no database and no models of its own**: it
shows the shop and sells through the Platform's Storefront API with `storefront_kit`. Your job is
the look and the buyer's experience. The people asking are usually not programmers: build what
they ask for completely and explain the result in plain language. Reply in the language they write
in, but build the storefront in English (see "Language").

## The one rule: the look is yours, the data is the Platform's

- **Only use what the API gives** (`storefront_kit`, below; the full list of fields is in
  `vendor/blocks/storefront_kit/lib/storefront_kit/records.rb` and the Platform's docs). Never add
  a database, a model that stores anything, a migration, `db/seeds.rb`, or another way to keep
  data (files, browser storage for anything but a convenience). Never hard-code products, prices,
  stock, shipping rates, reviews or policies in views: they change in the admin.
- **When something needs data the API doesn't have** (a field on products, a setting, a kind of
  page, a new kind of form), don't fake it. File a request with the Platform, in English, one per
  need, saying what the owner wants and what data would make it possible:

  ```sh
  bin/request "Products need a 'material' field the owner can fill in, to show 'Made of 100% cotton' on the product page"
  ```

  It shows in the shop's admin under Requests. Build the rest, and tell the owner in your reply
  what's waiting on the Platform. What the owner should be able to change without you (headline
  text, a banner image, an accent color, a section on/off) is a theme setting instead (below).
- **Never put secrets, keys or the owner's settings in the code** (Stripe, Printify, pixels, the
  shop's key). The owner sets them in the shop's admin. Never ask for them in the chat.

## storefront_kit

- In controllers (the `Storefront` concern): `current_shop`, `current_cart` (nil before the
  buyer adds anything), `current_cart!`, and `storefront`, the API:
  `storefront.products(q:, collection:, sort:, page:, per_page:)` (a `ListPage` of `Product`),
  `storefront.product(slug)`, `storefront.collections`, `storefront.collection(slug)`,
  `storefront.reviews(slug)`, `storefront.page(slug)`, `storefront.menu(key)`,
  `storefront.policy(id)`, `add_to_cart`, `update_cart_item`, `remove_cart_item`,
  `apply_discount`, `quote`, `place_order`, `order(token)`, `payment(token)`, `review_order`,
  `submit_form(key, answers)`.
- In views (`StorefrontHelper`): `current_shop` (name, currency, announcement, shipping,
  pixels, policies, contact), `theme_setting(:key)`, `money(cents)`, `price_range(product)`,
  `product_image(product, size: :thumb|:card|:large)`, `shop_menu(:header)`, `products(...)`,
  `collections` for a section of any page.
- Records read every field of the API as a method: `product.title`, `variant.available?`,
  `product.variant_for(%w[ Black M ])`, `product.image_for(variant)`, `cart.items`,
  `order.tracking`. `StorefrontKit::NotFound` becomes a 404 by itself; `StorefrontKit::Invalid`
  has `fields` (what to fix) for a form.
- Catalog reads are cached for a few seconds in the published shop and fresh in the preview.
  Make a page's API calls in its controller (or one helper call per section), not in loops.

## Theme settings and forms (applied when the storefront is published)

- `config/theme_settings.yml` declares what the owner can change in the admin (Settings → Theme):
  `- { key: hero_title, type: text, label: Home page headline, default: "…" }`. Types: `text`,
  `richtext`, `image`, `color`, `url`, `boolean`, `select` (with `options`). Read them with
  `theme_setting(:hero_title)`. Give every one a sensible default; a key you rename loses what the
  owner set.
- `config/forms.yml` declares the forms the storefront sends to the shop (contact, a wholesale
  enquiry): `key`, `title`, `fields` (`text`, `email`, `textarea`, `boolean`). Post them to
  `form_submissions_path(key)` with `answers[<field>]`; messages land in the admin's inbox and the
  owner's email.
- The owner's own pages (`/pages/:slug`), menus (`shop_menu(:header)`, `:footer`), policies and
  collections are made in the admin; link to them, don't recreate them.

## Language

The storefront is in English, everywhere, even when the owner writes to you in another
language. Translate what they ask for into natural English copy; keep names they give as they
wrote them. The built-in screens use `config/locales/en.yml` through `t(...)`; write new copy
directly in the view. Format with `l(date)` and `money(cents)`.

## Stack (fixed)

Rails 8.1 without Active Record, Hotwire (Turbo + Stimulus), importmap, Tailwind CSS 4,
Minitest. Do not add JavaScript frameworks, Node build steps, databases or external services.

## Commands

- `bin/rails test`: every test, against a Platform in memory (`StorefrontKit::Testing::FakeApi`,
  `@platform` in tests: set its data up in the test, read what was sent in `@platform.requests`)
- `bin/look /path`: screenshots of the running preview at phone and desktop width (Read them) and
  the problems a visitor would hit; `bin/look https://…` screenshots another site
- `bin/rubocop`: style, must be clean
- `bin/rails tailwindcss:build`: after changing views
- `bin/request "…"`: ask the Platform for data the API doesn't have (above)

## What's built in (keep it working when you redesign)

Most buyers arrive from an ad on a phone, look at one product page and decide in seconds. Restyle
these for the brand, but keep each part:

- **Product page**: photos (each color's photo when a color is picked), price with the sale price
  and "Save 20%", swatches (`swatch_color`) and size buttons, the text buyers type to be printed
  (`product.buyer_inputs`), the add-to-cart button and right under it when it arrives
  (`delivery_estimate`), shipping and returns; the size guide in a dialog; the sticky buy bar on
  phones (`sticky-buy`); reviews (never invent any) and "You may also like".
- **Cart**: the free-shipping bar, discount codes, trust lines by the checkout button.
- **Checkout** (`checkouts/new`): the address with US ZIP autofill, the totals partial that reloads
  with Printify's real shipping (`checkouts/_totals`), payment by card (Stripe's Payment Element at
  `/orders/:token/payment`) or the shop's instructions. Don't change how it places orders or pays.
- **Order page**, **reviews**, **policies** and **contact** pages, the announcement bar, the
  footer links to the policies and contact page (Stripe and ad networks check them).
- **Ad tracking**: keep `layouts/site/tracking_tags` in the head and `tracking_events` in the body,
  and `track` in the controllers; `/feeds/products.xml` and the product page's schema.org data.
- **No products yet**: the shop shows `products/_coming_soon` until the owner's products are in.
  Never invent products, prices, photos or reviews to fill the preview.

Don't add fake urgency or fake social proof (invented stock counts, countdowns that reset,
made-up reviews or "23 people are viewing this"): ad networks and Stripe ban shops for it.
Printed-to-order products can't be returned for a wrong size: never promise size exchanges.

## Running on ONCE (do not break)

- It serves HTTP on port 80 through Thruster; `/up` answers 200 when it's healthy.
- Configuration comes from the environment: `PLATFORM_URL`, `SHOP_KEY`, `STOREFRONT_MODE`,
  `SECRET_KEY_BASE`, `DISABLE_SSL`. Never hard-code hosts or keys.
- `config/initializers/preview_probe.rb` and `preview_gate.rb` serve the builder's preview; leave
  them as they are. Use `bin/look` to see pages (a plain request to the preview answers 403).

## SPEC.md: what was asked and what was chosen

SPEC.md is the storefront's checklist, kept across turns. At the start of every turn that builds
or changes something, add under **Asked** each thing the owner asked for in this message, one line
each, close to their words (`- [ ] Black home page, brass accents, no pink`), and under **Chosen**
what you decided where they said nothing. Before you finish, tick (`- [x]`) each line only when
it's true in the running storefront (`bin/look`, the tests). A line that waits on a Platform
request stays unticked; say so. The owner's words outrank everything else here.

## Design

Every storefront gets a look of its own, chosen for the shop and its buyers. Read `DESIGN.md`
before touching views; on a new storefront it says "Not decided yet": choose the direction with
the `design` skill first and write it there. The theme (colors, fonts, corners) is in
`app/assets/tailwind/application.css`; icons are Lucide via `icon "name"` (`bin/icons <word>`);
free stock photos come from `bin/images <english words>`; page blocks to start from are in
`app/views/blocks/` (seen at `/_blocks`). Design at 390px wide first.

## Definition of done

- Every line under Asked in SPEC.md is ticked, or your reply says why it isn't.
- It works end to end in the preview, including empty states (no products, an empty cart).
- Tests for what you changed (`test/controllers/`), with the Platform in memory; `bin/rails test`
  and `bin/rubocop` pass.
- You looked at every page you changed with `bin/look`, at phone and desktop width, and fixed what
  it reported.
- Your reply says what changed in plain words, and what's waiting on a Platform request.
