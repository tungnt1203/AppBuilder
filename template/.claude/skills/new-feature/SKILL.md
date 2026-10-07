---
name: new-feature
description: Add a new screen or resource (model, migration, controller, views, navigation, tests) to this app the conventional way. Use whenever the owner asks for something the app should track or show, like "reviews", "discount codes", "a size guide".
---

# Adding a feature

The shop (products, cart, checkout, orders, settings) is already built; see "The shop" in
CLAUDE.md and extend it rather than adding a second one. Work through these steps in order. Skipping the tests or the empty state is the most common way a
feature ends up half-done.

## 1. Decide the shape

- What records exist and how they relate (`Review belongs_to :product`).
- Which half each screen belongs to (CLAUDE.md, "Two halves"). Most features have both: buyers
  write reviews on the site (`Products::ReviewsController`), the owner approves them in /admin
  (`Admin::ReviewsController`). Same models, separate controllers, views and tests.
- Who may see and change what: on the site, any visitor (buying never needs an account; a buyer
  reaches their order by its unguessable link), or, when the app has customer accounts, only the
  signed-in customer and only their own records; in /admin, all staff or only admins
  (`before_action :require_administrator`). Site pages must work with no accounts in the app.
- What a person does on each screen. Prefer fewer screens: index with inline actions over many pages.

Where the request leaves something open, choose what suits the owner best, build it, and list it
under Chosen in SPEC.md; don't stop to ask about what you can reasonably choose.

## 2. Model and migration

Generate, then edit by hand: `bin/rails generate model Review product:references name:string rating:integer body:text status:string`.

- `null: false` on required columns, sensible defaults, indexes for foreign keys and anything you
  filter or sort by.
- Statuses are string enums: `enum :status, %w[ pending approved hidden ].index_by(&:itself), default: "pending"`.
- Money is integer cents with `money_attribute` (CLAUDE.md, "The shop").
- Validations for every rule the owner mentioned. Business logic lives in the model, not the controller.
- Add `scope :ordered` (or a better-named scope) for the default sort.
- Migrations must stay backward compatible (see CLAUDE.md).

## 3. Controller

Plain RESTful actions only; add a new controller rather than custom actions
(`Admin::Orders::ShipmentsController#create`, not `Admin::OrdersController#ship`).

The owner's side, in `app/controllers/admin/`:

```ruby
class Admin::ReviewsController < Admin::BaseController
  before_action :set_review, only: %i[ update destroy ]

  def index
    @page = paginate(Review.ordered.includes(:product), per: 50)
  end

  def update
    @review.update!(params.expect(review: [ :status ]))
    redirect_to admin_reviews_path, notice: "Review updated.", status: :see_other
  end

  def destroy
    @review.destroy!
    redirect_to admin_reviews_path, notice: "Review deleted.", status: :see_other
  end

  private
    def set_review
      @review = Review.find(params[:id])
    end
end
```

The site's side, in `app/controllers/`. Public pages show only what visitors may see, and find
products by slug the way `ProductsController` does:

```ruby
class Products::ReviewsController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: :create

  def create
    @product = Product.visible.find_by!(slug: params[:product_id])
    @review = @product.reviews.new(params.expect(review: [ :name, :rating, :body ]))

    if @review.save
      redirect_to product_path(@product), notice: "Thanks! Your review shows once it's approved."
    else
      redirect_to product_path(@product), alert: @review.errors.full_messages.to_sentence
    end
  end
end
```

A buyer's own records (an order, a download) are found by an unguessable token, never by id
(`Order.find_by!(token: params[:id])`); with customer accounts on, through `Current.customer`.

## 4. Views

Site pages follow DESIGN.md (`design` skill). /admin screens (`app/views/admin/reviews/`) use the
UI kit (`ui-kit` skill). Every index needs an empty state; every form shows errors.

```erb
<%# app/views/admin/reviews/index.html.erb %>
<%= page_header "Reviews", "Approve reviews before they show on product pages." %>

<% if @page.records.any? %>
  <%= card padded: false do %>
    <ul class="divide-y divide-line">
      <%= render partial: "admin/reviews/review", collection: @page.records %>
    </ul>
  <% end %>
  <%= render "ui/pagination", page: @page %>
<% else %>
  <%= empty_state "No reviews yet", "Reviews buyers write show up here." %>
<% end %>
```

```erb
<%# app/views/products/_review_form.html.erb, on the product page %>
<%= form_with model: [ product, Review.new ], url: product_reviews_path(product), class: "space-y-4" do |form| %>
  <%= form.field :name, required: true %>
  <div class="space-y-1.5">
    <%= form.label :rating %>
    <%= form.select :rating, 5.downto(1).map { |stars| [ "★" * stars, stars ] } %>
  </div>
  <%= form.field :body, :text_area, rows: 4, required: true %>
  <%= form.submit "Send review" %>
<% end %>
```

`form.field` takes the input method name as its second argument; for `select` and `collection_select`
write the `label` and input separately inside `<div class="space-y-1.5">`.

## 5. Routes and navigation

- Site routes at the top of `config/routes.rb`, nested where they belong:

  ```ruby
  resources :products, only: %i[ index show ] do
    resources :reviews, only: :create, module: :products
  end
  ```

  Admin routes inside `namespace :admin` (`resources :reviews, only: %i[ index update destroy ]`).
- `<%= nav_link_to "Reviews", admin_reviews_path, match: "/admin/reviews" %>` in
  `app/views/layouts/admin/_navigation.html.erb`. `match:` keeps the link active on the nested pages.
  Wrap groups of links in `nav_section` once the sidebar has more than a handful.
- Site links go in the site header (`app/views/layouts/site/_header.html.erb`) or on the pages.
- If this is now the site's main page, point `root` at it; the admin dashboard is `admin/root`.

## 6. Tests

- `test/models/review_test.rb`: each validation and business rule.
- `test/controllers/admin/reviews_controller_test.rb`: every action, signed in via
  `sign_in_as users(:staff)`, plus the access rules (signed out goes to sign in; a signed-in customer
  is not let in; admin-only stays admin-only).
- `test/controllers/products/reviews_controller_test.rb` (and the other site controllers): as a
  visitor with no accounts at all; a buyer's own records open by their token and not by their id. With customer accounts
  on (`setup { enable_customer_accounts }`), also as a customer via
  `sign_in_as_customer customers(:casey)`, who never sees `customers(:jordan)`'s records (404).
- Fixtures in `test/fixtures/reviews.yml` that reference the shop's fixtures: `products(:tee)`,
  `products(:mug)`, `variants(:tee_black_s)`, `orders(:pending)`, `users(:owner)`, `users(:staff)`.
- `test/system/<flow>_test.rb`: a system test for each main flow, walked through in the browser the way
  people do it, from the page they start on to the result they expect. For reviews: a visitor
  opens a product on a phone (`on_phone { … }`), writes a review, sees the thank-you; then the owner
  signs in to /admin (`sign_in_as users(:owner)`), approves it, and it shows on the product page.
  `test/system/shopping_test.rb` walks the built-in buying flow; keep it passing. Also one
  mistake (a missing field shows its error). Use `click_on`, `fill_in`, `select`, `assert_text` with the
  words on screen. JavaScript errors fail these tests, so Stimulus code gets exercised too.

Run `bin/rails test`, `bin/rails test:system` and `bin/rubocop`, then `bin/rails tailwindcss:build`.

## 7. Try it

Look at what you built in the running app, the way its users will: `bin/look` with the pages you
added or changed, as a visitor for site pages (`bin/look /products/cat-mom-tee`), as a customer for their pages when the app has
customer accounts (`bin/look /account --as customer`), and signed in to /admin for staff pages
(`bin/look /admin/reviews --as owner`). It reports error pages, JavaScript errors, broken images and links,
and pages wider than a phone, and saves screenshots at phone and desktop width: Read them. Check the
empty state and a page with a few records (add them in `db/seeds.rb` and run `bin/rails db:seed` when
the app has none). Fix everything it finds and anything that looks wrong, then look again.

## 8. Summary for the owner

Tick what's done under Asked in SPEC.md first (CLAUDE.md). Then tell them what they can do now and
where to find it, in their language, and the choices they may want to change. Mention anything that changes existing
data or needs their action (for example, settings to fill in).
