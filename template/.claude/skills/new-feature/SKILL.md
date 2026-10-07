---
name: new-feature
description: Add a new screen or resource (model, migration, controller, views, navigation, tests) to this app the conventional way. Use whenever the owner asks for something the app should track or show, like "products", "orders", "a booking page".
---

# Adding a feature

Work through these steps in order. Skipping the tests or the empty state is the most common way a
feature ends up half-done.

## 1. Decide the shape

- What records exist and how they relate (`Order belongs_to :customer`, `Order has_many :line_items`).
- Which half each screen belongs to (CLAUDE.md, "Two halves"). Most features have both: customers
  browse and order on the site (`ProductsController`, `OrdersController`), the owner manages them in
  /admin (`Admin::ProductsController`, `Admin::OrdersController`). Same models, separate controllers,
  views and tests.
- Who may see and change what: on the site, any visitor (buying never needs an account; a buyer
  reaches their order by its unguessable link), or, when the app has customer accounts, only the
  signed-in customer and only their own records; in /admin, all staff or only admins
  (`before_action :require_administrator`). Site pages must work with no accounts in the app.
- What a person does on each screen. Prefer fewer screens: index with inline actions over many pages.

Where the request leaves something open, choose what suits the owner best, build it, and list it
under Chosen in SPEC.md; don't stop to ask about what you can reasonably choose.

## 2. Model and migration

Generate, then edit by hand: `bin/rails generate model Appointment customer:references starts_at:datetime notes:text`.

- `null: false` on required columns, sensible defaults, indexes for foreign keys and anything you
  filter or sort by.
- Statuses are string enums: `enum :status, %w[ booked confirmed cancelled ].index_by(&:itself), default: "booked"`.
- Validations for every rule the owner mentioned. Business logic lives in the model, not the controller.
- Add `scope :ordered` (or a better-named scope) for the default sort.
- Migrations must stay backward compatible (see CLAUDE.md).

## 3. Controller

Plain RESTful actions only; add a new controller rather than custom actions
(`Admin::Orders::ShipmentsController#create`, not `Admin::OrdersController#ship`).

The owner's side, in `app/controllers/admin/`:

```ruby
class Admin::ProductsController < Admin::BaseController
  before_action :set_product, only: %i[ show edit update destroy ]

  def index
    @products = Product.ordered
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to admin_products_path, notice: "Product added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # show, edit, update, destroy follow the same pattern.
  # destroy redirects with status: :see_other.

  private
    def set_product
      @product = Product.find(params[:id])
    end

    def product_params
      params.expect(product: [ :name, :price, :description ])
    end
end
```

The customers' side, in `app/controllers/`. Public pages show only what visitors may see. A guest's
order is found by its token (`has_secure_token :token` on `Order`), never by id:

```ruby
class ProductsController < ApplicationController
  def index
    @products = Product.published.ordered
  end

  def show
    @product = Product.published.find(params[:id])
  end
end

class OrdersController < ApplicationController
  def show
    @order = Order.find_by!(token: params[:id]) # order_path(order.token)
  end
end
```

## 4. Views

Site pages (`app/views/products/`) follow DESIGN.md (`design` skill). /admin screens
(`app/views/admin/products/`) use the UI kit (`ui-kit` skill). Every index needs an empty state;
every form shows errors.

```erb
<%# app/views/admin/products/index.html.erb %>
<%= page_header "Products", "What's for sale on the site." do %>
  <%= link_to "Add product", new_admin_product_path, class: button_classes %>
<% end %>

<% if @products.any? %>
  <%= card padded: false do %>
    <ul class="divide-y divide-line">
      <%= render partial: "admin/products/product", collection: @products %>
    </ul>
  <% end %>
<% else %>
  <%= empty_state "No products yet", "Products you add show up on the site." do %>
    <%= link_to "Add the first one", new_admin_product_path, class: button_classes %>
  <% end %>
<% end %>
```

```erb
<%# app/views/admin/products/_form.html.erb %>
<%= form_with model: [ :admin, product ], class: "space-y-4" do |form| %>
  <%= form.errors %>
  <%= form.field :name, required: true %>
  <%= form.field :price, :number_field, step: 0.01, min: 0, required: true %>
  <div class="space-y-1.5">
    <%= form.label :category_id, "Category" %>
    <%= form.collection_select :category_id, Category.ordered, :id, :name, prompt: "Choose a category" %>
  </div>
  <%= form.field :description, :text_area, rows: 4 %>
  <%= form.submit %>
<% end %>
```

`form.field` takes the input method name as its second argument; for `select` and `collection_select`
write the `label` and input separately inside `<div class="space-y-1.5">`.

## 5. Routes and navigation

- Site routes at the top of `config/routes.rb` (`resources :products, only: %i[ index show ]`),
  admin routes inside `namespace :admin` (`resources :products`).
- `<%= nav_link_to "Products", admin_products_path, match: "/admin/products" %>` in
  `app/views/layouts/admin/_navigation.html.erb`. `match:` keeps the link active on the nested pages.
  Wrap groups of links in `nav_section` once the sidebar has more than a handful.
- Site links go in the site header (`app/views/layouts/site/_header.html.erb`) or on the pages.
- If this is now the site's main page, point `root` at it; the admin dashboard is `admin/root`.

## 6. Tests

- `test/models/appointment_test.rb`: each validation and business rule.
- `test/controllers/admin/products_controller_test.rb`: every action, signed in via
  `sign_in_as users(:staff)`, plus the access rules (signed out goes to sign in; a signed-in customer
  is not let in; admin-only stays admin-only).
- `test/controllers/products_controller_test.rb` (and the other site controllers): as a visitor with
  no accounts at all; an order's page opens by its token and not by its id. With customer accounts
  on (`setup { enable_customer_accounts }`), also as a customer via
  `sign_in_as_customer customers(:casey)`, who never sees `customers(:jordan)`'s records (404).
- Fixtures in `test/fixtures/products.yml` that reference `users(:owner)`, `users(:staff)`,
  `customers(:casey)`, `customers(:jordan)`.
- `test/system/<flow>_test.rb`: a system test for each main flow, walked through in the browser the way
  people do it, from the page they start on to the result they expect. For a shop: a visitor
  opens a product on a phone (`on_phone { … }`), adds it to the cart, checks out, sees the
  confirmation; then the owner signs in to /admin (`sign_in_as users(:owner)`) and finds the order. Also one
  mistake (a missing field shows its error). Use `click_on`, `fill_in`, `select`, `assert_text` with the
  words on screen. JavaScript errors fail these tests, so Stimulus code gets exercised too.

Run `bin/rails test`, `bin/rails test:system` and `bin/rubocop`, then `bin/rails tailwindcss:build`.

## 7. Try it

Look at what you built in the running app, the way its users will: `bin/look` with the pages you
added or changed, as a visitor for site pages (`bin/look /products`), as a customer for their pages when the app has
customer accounts (`bin/look /account --as customer`), and signed in to /admin for staff pages
(`bin/look /admin/products /admin/products/new --as owner`). It reports error pages, JavaScript errors, broken images and links,
and pages wider than a phone, and saves screenshots at phone and desktop width: Read them. Check the
empty state and a page with a few records (add them in `db/seeds.rb` and run `bin/rails db:seed` when
the app has none). Fix everything it finds and anything that looks wrong, then look again.

## 8. Summary for the owner

Tick what's done under Asked in SPEC.md first (CLAUDE.md). Then tell them what they can do now and
where to find it, in their language, and the choices they may want to change. Mention anything that changes existing
data or needs their action (for example, settings to fill in).
