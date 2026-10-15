# Storefront API v1

What a shop's storefront calls to show the shop and take its orders. It runs on the Platform
(`StorefrontApi::V1::*` in `builder/`); the design is in [platform-v1.md](platform-v1.md).

## Basics

- **Key**: every request sends the shop's key, `Authorization: Bearer sk_shop_…`. Owners and
  admins make keys in the shop's admin, Settings › Storefront keys. A key is shown once.
  - `sk_shop_…` is for the published storefront.
  - `sk_preview_…` is for the builder's preview. Its orders are **test orders**: they are never
    sent to Printify, never reported to Meta and never counted in sales. They can only be paid in
    Stripe's test mode.
- **JSON** in and out. Send bodies with `Content-Type: application/json`.
- **Money** is in cents, with its `currency`: `{ "subtotal_cents": 4800, "currency": "USD" }`.
- **Photos** come as absolute URLs in three sizes: `{ "id", "alt", "thumb", "card", "large" }`
  (160×160, 640×800, up to 1400×1400, WebP).
- **Errors**: `{ "error": { "code": "invalid", "message": "…", "fields": { "email": "is invalid" } } }`.
  `fields` is only there when a field is at fault.

  | Status | Codes |
  |---|---|
  | 400 | `bad_request` (a required parameter is missing) |
  | 401 | `unauthorized` |
  | 404 | `not_found` |
  | 409 | `unavailable` (can't be bought now), `in_progress` (same Idempotency-Key still running) |
  | 422 | `invalid`, `unknown`, `expired`, `not_started`, `used_up`, `below_minimum`, `idempotency_key_reused`, `payment_not_needed`, `card_payments_unavailable`, `test_mode_unavailable`, `nothing_to_review` |
  | 429 | `rate_limited` (600 requests a minute per key) |
  | 502 | `payment_failed` (Stripe refused) |

- **ETags**: every GET answers with an `ETag`. Send it back as `If-None-Match` to get a
  `304 Not Modified` when nothing changed.
- **Idempotency**: placing an order and starting a payment take an `Idempotency-Key` header.
  - The same request sent again with the same key gets the first answer back, marked
    `Idempotent-Replayed: true`, and no second order or payment is made.
  - The same key with a different request is refused with `idempotency_key_reused`.
  - Keys are kept for a day.

## Endpoints

| Method and path | What it does |
|---|---|
| `GET /v1/shop` | The shop: name, currency, announcement, shipping, payment methods, pixels, policies, contact |
| `GET /v1/products` | Products on sale. Query: `q`, `collection` (slug), `sort` (`newest`, `title`, `price_asc`, `price_desc`), `page`, `per_page` (max 100) |
| `GET /v1/products/:slug` | One product: options (with colors), variants, photos, size guide, collections, rating |
| `GET /v1/products/:slug/reviews` | Its published reviews, newest first, 10 a page |
| `GET /v1/collections` | Collections in the shop's order, with how many products on sale each has |
| `GET /v1/collections/:slug` | One collection. Its products: `/v1/products?collection=:slug` |
| `GET /v1/policies/:id` | `refund`, `shipping`, `privacy` or `terms`, when the shop wrote it |
| `GET /v1/zip_codes/:zip` | A US ZIP code's city and state, to fill in checkout |
| `POST /v1/carts` | A new cart. Keep its `token` in the buyer's session |
| `GET /v1/carts/:token` | The cart |
| `POST /v1/carts/:token/items` | Add `{ variant_id, quantity }` |
| `PATCH /v1/carts/:token/items/:id` | Set a line's `{ quantity }` (0 takes it out) |
| `DELETE /v1/carts/:token/items/:id` | Take a line out |
| `POST /v1/carts/:token/discount` | Apply `{ code }` |
| `DELETE /v1/carts/:token/discount` | Remove the code |
| `POST /v1/checkouts/quote` | What the cart comes to for the address so far: `{ checkout, problems }` |
| `POST /v1/checkouts` | Place the order (Idempotency-Key) |
| `GET /v1/orders/:token` | The buyer's order. A card order not paid yet is checked with Stripe first |
| `POST /v1/orders/:token/payment` | The card payment for the Payment Element (Idempotency-Key) |
| `POST /v1/orders/:token/reviews` | Review what was bought, once it's on its way |

Every change to a cart answers with the whole cart.

Coming with Platform v1 (4/10): theme settings in `/v1/shop`, product custom fields and buyer
inputs, `GET /v1/pages/:slug`, `GET /v1/menus/:key`, `POST /v1/forms/:key/submissions`.

## Shapes

**Product (in a list)**

```json
{ "slug": "cat-mom-tee", "title": "Cat Mom Tee", "available": true,
  "price": { "min_cents": 2400, "max_cents": 2600, "currency": "USD", "compare_at_cents": 3000 },
  "image": { "id": 1, "alt": "Cat Mom Tee", "thumb": "https://…", "card": "https://…", "large": "https://…" },
  "rating": { "average": 4.6, "count": 12 } }
```

`compare_at_cents` is the highest "was" price of a variant on sale (null when none is).
`rating` is null before the first review.

**Product (one)** has all of the above, plus:

- `description`, `size_guide` and `size_option` (the option a size guide is for, e.g. "Size").
- `options`: `[{ "name": "Color", "values": ["Black"], "colors": { "Black": "#000000" } }]`.
- `variants`: `[{ "id", "title": "Black / S", "options": ["Black", "S"], "sku", "price_cents", "compare_at_price_cents", "available", "stock", "image_id" }]`.
  - `stock` is only there when stock is low.
  - `image_id` is the photo that shows that variant.
- `images`: photos, each with `option_value`, the option value it shows.
- `collections`: `[{ "slug", "title" }]`.

**Cart**: `{ token, currency, items: [{ id, quantity, line_total_cents, product: { slug, title, image }, variant }], item_count, subtotal_cents, discount: { code, kind, amount_cents }, free_shipping_remaining_cents }`.
Only lines that can still be bought are there.

**Checkout quote**: `{ checkout: { items, subtotal_cents, discount_cents, discount_code, shipping_cents, shipping_known, total_cents, payment_methods, phone_required }, problems: { field: message } }`.

- Shipping is Printify's real price once the address is complete enough to quote
  (`shipping_known: true`). Until then it's the shop's flat rate.
- `phone_required` is true when Printify items are in the cart: its carriers need the buyer's phone.

**Placing an order**: `POST /v1/checkouts` with:

- `cart_token`
- `email`, `phone`
- `shipping_name`, `shipping_address1`, `shipping_address2`, `shipping_city`, `shipping_region`,
  `shipping_postal_code`, `shipping_country`
- `note`
- `payment_method` (`stripe` or `manual`)
- `attribution: { fbp, fbc, ip, user_agent, url }` (the buyer's browser, for Meta's Conversions API)

Answers `201 { order }` or `422` with `fields`.

**Order**: `{ token, number, name, status, test, placed_at, paid_at, shipped_at, delivered_at, cancelled_at, refunded_at, email, currency, items, subtotal_cents, discount_cents, discount_code, shipping_cents, tax_cents, total_cents, refunded_cents, shipping_address, payment: { method, required, instructions }, tracking: { carrier, number, url }, reviewable_products: [{ slug, title }] }`.

- `status` is one of `pending`, `paid`, `in_production`, `shipped`, `delivered`, `cancelled`,
  `refunded`.
- `payment.required` is true while a card order waits to be paid.
- `payment.instructions` is how to pay a manual order that is still pending.

## Paying by card

1. Place the order with `payment_method: "stripe"`.
2. `POST /v1/orders/:token/payment` answers
   `{ payment: { provider: "stripe", client_secret, publishable_key, amount_cents, tax_cents, currency, test_mode } }`.
   - With Stripe Tax on in the shop's settings, the tax is worked out here and added to the order.
   - The same order always gets the same PaymentIntent.
3. Mount Stripe's Payment Element with `publishable_key` and `client_secret`, and confirm it with
   `return_url` set to the order's page.
4. On the order's page, `GET /v1/orders/:token` checks the payment with Stripe and shows the
   order `paid`. Stripe's webhook will confirm it too (Platform v1, 7/10).

A card order that isn't paid gets one reminder email after an hour, and is cancelled a day after
it was placed.
