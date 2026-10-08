# CLAUDE.md

This is a Rails 8 app, an online shop to start with (see "The shop"), that its owner self-hosts
with ONCE (https://github.com/basecamp/once).
The people describing features are usually not programmers: build what they ask for as a
complete, working feature, and explain the result in plain language. Reply to the owner in the
language they write in, but build the app itself in English (see "Language and time zone").

## SPEC.md: what was asked and what was chosen

SPEC.md is the app's checklist, kept across turns. At the start of every turn that builds or
changes something:

- Under **Asked**, add each thing the owner asked for in this message, one line each, close to
  their words and with their specifics (names, prices, colors, sections, rules, who may do what):
  `- [ ] Black home page, brass accents, no pink`. When they change their
  mind, change or remove the old line; never keep two lines that disagree.
- Under **Chosen**, list what you decided where they said nothing that matters to them: who can
  sign up, what's public, the look, sample content: `- Buyers check out without an account`.

Before you finish, check every unchecked line under Asked against the app itself (the running
app with `bin/look`, the tests, the code), and tick it (`- [x]`) only when it's true there. A line
you can't meet stays unticked; say why in your reply. Answers to your questions and approved
plans count as asked. Never tick for the owner what you only planned.

The owner's words outrank everything else here, the skills' suggestions and the page blocks
included: when they ask for something unusual, build that rather than what such apps usually look
like. If it would hurt the people using the app (text too pale to read, a page that breaks on
phones), build it as close as works and say why.

## Language and time zone

The app is in English, everywhere: the site, /admin, emails, sample content, product names and
the app's name, even when the owner writes to you in another language. Translate what they ask
for into natural English copy; keep names they give (a brand, a person) as they wrote them. Write
in another language only when the owner explicitly asks for the app itself to be in it.

- `config.time_zone`: the owner's, e.g. `"Asia/Ho_Chi_Minh"`; order times in /admin use it.

The built-in screens use `config/locales/*.yml` through `t(...)`, and Rails covers its own
messages, dates and numbers. Write new copy directly in the view. Format with `l(date)`,
`l(time, format: :short)` and `money(cents)`.

## Stack (fixed)

Rails 8.1, SQLite, Solid Queue/Cache/Cable, Hotwire (Turbo + Stimulus), importmap, Tailwind CSS 4,
Minitest with fixtures. Do not add JavaScript frameworks, Node build steps, other databases,
Redis, or external services. Add a gem only when Rails cannot reasonably do the job.

## Commands

- `bin/rails test` — all tests; must pass before you report a task as done
- `bin/rails test:system` — the main flows in headless Chrome (`test/system/`); must pass too
- `bin/look /path` — look at pages of the running app: screenshots at phone and desktop width (Read
  them) and the problems a visitor would hit. `--as customer` signs in a customer, `--as owner` (or
  `admin`, `staff`) signs in to `/admin`
- `bin/rubocop` — style; must be clean
- `bin/rails db:migrate` — after adding a migration
- `bin/rails tailwindcss:build` — after changing views, so the preview picks up new classes

## Running on ONCE (do not break)

- The app serves HTTP on port 80 through Thruster; `/up` must return 200 when the app is healthy.
- Everything that must survive restarts lives in `storage/` (SQLite databases, uploads). Never write
  persistent data anywhere else.
- Configuration comes from environment variables ONCE sets: `BASE_URL`, `SMTP_*`,
  `MAILER_FROM_ADDRESS`, `DISABLE_SSL`, `SECRET_KEY_BASE`. Never hard-code hosts, credentials or secrets.
- `hooks/pre-backup` and `hooks/post-restore` keep backups consistent; leave them alone.
- `config/initializers/preview_probe.rb` reports errors to the builder's preview in development; leave it as it is.
- `config/initializers/preview_gate.rb` keeps the preview private in development; leave it as it is.
  Use `bin/look` to see pages (it gets through); a plain request to the preview answers 403.

## Migrations must be backward compatible

When a new version fails its health check, ONCE keeps the previous version running, but migrations
from the new version may already have run. The previous code must keep working on the new schema:

- Adding tables, adding columns with a default or that allow NULL, and adding indexes are fine.
- Never remove or rename a column or table in the same change that stops using it. Stop using it first;
  removing it is a separate, later change.
- Never change existing data in a way the previous version can't read.

## Two halves: the customers' site and /admin

Every app has two halves that share the database and nothing else: their own accounts, sign in,
layout and look. Decide for every screen which half it belongs to.

- **The customers' site**: everything outside `/admin`. Home, catalog, product pages, cart,
  checkout, booking, order status, and customer accounts when the app has them. Controllers inherit from
  `ApplicationController`; pages are **public** by default. Designed freely (`design` skill).
- **/admin**: where the owner and staff run the app. Managing products, orders, customers,
  schedules, reports, settings. Controllers live in `app/controllers/admin/`, inherit from
  `Admin::BaseController`, and route under `namespace :admin`. Sign in is required; they use the
  UI kit (`ui-kit` skill). A staff screen never goes outside `/admin`, and a customer's screen
  never goes inside it.

The customers' site must work for any visitor on a brand-new install with no accounts at all.
It never sends visitors to `/admin`, and has no link to it; the owner goes to `/admin` directly
(a new install starts the owner's first-run setup there). Test site pages with no users
(`User.delete_all`).

## The shop (built in)

Every app starts as a working shop. Build on it; don't write a second cart, checkout or order model.

The shop's core (its models, payments, order emails and migrations) is the `shop` gem in
`vendor/blocks/shop`. Read it to see how things work; never change, move or copy its files. It's
the same in every app and gets updated as a whole, so a change there would be lost. The app's own
files build on it:

- **Screens**: the site's and /admin's controllers and views are the app's (`app/`); change them freely.
- **Adding to a core model** (an association, validation, scope, method, a column from a new
  migration): in `app/models/<model>/extension.rb`, which the core includes:
  `module Product::Extension; extend ActiveSupport::Concern; included { has_many :reviews, dependent: :destroy }; end`.
  Never create `app/models/product.rb` (or any file with the same path as one of the core's): it
  would replace the core's class, and the app refuses to start with one.
- **Order emails and the core's text**: copy a template from `vendor/blocks/shop/app/views/` to the
  same path in `app/views/` to change it; set the same key in `config/locales/` to change a message.

- **Catalog**: `Product` (title, description, photos as `images`, status draft/active/archived, up to
  three options like Color × Size) and its `Variant`s, one per combination of option values, each
  with its own price, compare-at price, SKU and "for sale" switch. Saving a product makes and
  removes variants to match its options (`Product#sync_variants`). `Collection` groups products.
  Products and collections are found by `slug` (`product_path(product)` uses it).
- **Cart and checkout**: `Cart` (signed cookie, `current_cart` / `current_cart!` in site controllers),
  `CartItem`, and `Checkout`, which turns a cart into an `Order` in one transaction. Prices, titles
  and totals always come from the database and are copied into the order's `LineItem`s.
- **Orders**: `Order` moves through `pending → paid → in_production → shipped → delivered` (or
  `cancelled`, `refunded`) only with its methods (`mark_paid!`, `start_production!`, `ship!`,
  `mark_delivered!`, `cancel!`, `refund!`), which check the step is allowed, record an `OrderEvent`
  in the timeline and send the buyer's emails (`OrderMailer`). Never set `status` directly. Buyers
  reach an order by its token (`order_path(order)`); staff at `/admin/orders`.
- **Money** is integer cents in `*_cents` columns, edited as decimals through `money_attribute`
  (`price` / `price=`), and shown with `money(cents)` and `price_range(product)` (`MoneyHelper`) in
  the shop's currency. Never use floats for money, and never total prices in a view.
- **Settings**: `Store.current` (currency, flat-rate shipping, free-shipping threshold, countries
  shipped to, how buyers pay), edited by admins at `/admin/settings`.
- **Payment** is built in and finished; don't change it for a feature. Buyers pay by card on
  Stripe Checkout once the owner pastes their Stripe secret key in `/admin/settings` (stored
  encrypted; the app registers its own webhook when it runs on a public https address), and/or
  manually with the store's payment instructions (staff mark those orders paid). A card order stays
  `pending` until Stripe confirms it (`Order#confirm_card_payment!`, from the order page or
  `StripeWebhooksController`); refunds of card orders go through Stripe. Every call to Stripe is in
  `StripeGateway` (in the core); tests use `connect_fake_stripe`. Never write other payment code, never ask the
  owner for keys in chat, and when they ask for card payments point them to Settings. For trying it
  out: a test key (`sk_test_…`) and card 4242 4242 4242 4242.
- **Policies**: refund, shipping, privacy and terms pages at `/policies/:id` and a `/contact` page,
  written by the owner at `/admin/settings/policies` (it starts them from print-on-demand
  templates). Keep the footer links to them when you redesign the footer: Stripe and ad networks
  check for them.
- **Fulfillment** is manual for now: staff move orders to production and add tracking when they
  ship. Print-on-demand providers plug in later; don't write provider API code in the app.
- **Development data**: `db/seeds.rb` adds a sample catalog for the preview. When the owner gives
  their real products, replace the samples there.

Change the shop's screens freely to fit the owner (design skill), keep its rules (prices from the
database, statuses through the methods, guest checkout), and add features around it: reviews,
discount codes, a size guide, gift notes, product pages that look like the owner's brand.

## Accounts

Two kinds, never mixed: a customer can't sign in to `/admin`, and a staff account isn't a customer.

- **Buyers need no account.** Anyone can buy, book or order as a guest: checkout asks for what the
  order needs (email, name, shipping address) and never for sign in. Each order gets a page the
  buyer reaches from the confirmation and the email, by an unguessable link
  (`has_secure_token` or `generates_token_for`), not by id. Never put sign in in the way of buying.
- **Customer accounts** are optional and off by default (`config.x.customer_accounts` in
  `config/application.rb`). Turn them on only when the owner asks for them or the app can't work
  without them (a member area, saved addresses, a wishlist, order history across visits). Then
  `Customer` / `CustomerSession` give sign up at `/registration/new`, sign in at `/session/new`,
  password reset at `/passwords/new` and `/account`; the site header shows sign in. Off, those
  pages answer 404. `Current.customer` is the signed-in customer (nil for guests); views check
  `customer_signed_in?`. A page only for signed-in customers adds `before_action :require_customer`.
  Records a customer owns use `belongs_to :customer, optional: true` (guests have none) and are
  looked up through it: `Current.customer.orders.find(params[:id])`. Show what customers come back
  for (orders, downloads) on `/account`, and still let them buy as guests unless the owner says
  otherwise. Tests of these pages call `enable_customer_accounts` in `setup`.
- **Owner and staff** (`User`, `Session`): `Current.user`, in `/admin` only. Roles: `owner` (created
  on first run, permanent), `admin`, `staff`; `user.administrator?` is true for owner and admin.
  Admins invite and manage staff at `/admin/users`. A controller only admins may use adds
  `before_action :require_administrator`. When staff should see only their own records, use
  `belongs_to :user` (or a clearer name like `:assignee`) and scope lookups through it.

## Design and UI

Every app gets a look of its own, chosen for its business and its customers. Read `DESIGN.md` before
touching views; on a new app it says "Not decided yet": choose the direction with the `design` skill
first and write it there. A plan for a new app includes a short "Look and feel" section.

- Theme (colors, fonts, corners): `app/assets/tailwind/application.css`. The template's theme is a
  neutral placeholder; replace it with the app's direction. Fonts are self-hosted (`fonts.css`); icons are Lucide via `icon "name"` (find names with `bin/icons <word>`); free stock
  photos come from `bin/images <english words>` (see the `design` skill).
- **The customers' site** (everything outside `/admin`) uses the `application` layout, the default
  for `ApplicationController`, and is designed freely: header, footer, sections, imagery, motion. Start from the page blocks in
  `app/views/blocks/` (seen at `/_blocks`), copied into the page and made the app's own. See the `design` skill.
- **/admin** uses the `admin` layout (sidebar), set by `Admin::BaseController`, and the UI kit in
  `app/helpers/ui_helper.rb` (`ui-kit` skill): `page_header`, `card`, `stat`, `empty_state`, `badge`,
  `alert`, `tabs`, `dialog`, `menu`, `button_classes`… Forms everywhere use `form.field`, `form.errors`,
  `form.submit` (`UiFormBuilder`). Add each admin screen to `app/views/layouts/admin/_navigation.html.erb`.
  Staff sign-in screens use `admin_authentication`.
- Interactivity comes from Turbo (Frames, Streams, morphing) and Stimulus (`shell`, `dialog`, `menu`,
  plus small controllers of your own).
- Set the app's name in `config.x.app_name` (`config/application.rb`).
- `root` is the shop's home page (`HomeController`: collections and newest products) and `/admin`'s is
  `Admin::DashboardsController` (sales and orders at a glance). Redesign the home page for the owner.

## Definition of done

- Every line under Asked in SPEC.md is ticked, or your reply says why it isn't.
- The feature works end to end from the browser, including empty states and validation errors.
- Model tests for validations and business rules; integration tests for each controller action,
  including who may and may not access it; a system test for each main flow (`new-feature` skill).
- `bin/rails test`, `bin/rails test:system` and `bin/rubocop` pass.
- You looked at every page you changed with `bin/look`, at phone and desktop width, both halves
  (owners run their shop from a phone too), and fixed what it reported and what looked wrong.
- Your summary says what changed in terms the owner understands, and flags anything that affects
  existing data.

Use the `new-feature` skill when adding a screen or resource, and the `design` skill for how it looks.
