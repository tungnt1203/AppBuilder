---
name: new-feature
description: Add a new screen or resource (model, migration, controller, views, navigation, tests) to this app the conventional way. Use whenever the owner asks for something the app should track or show, like "questions on product pages", "gift notes", "a lookbook".
---

# Adding a feature

The shop (products, cart, checkout, orders, discounts, reviews, settings) is already built; see "The shop" in
CLAUDE.md and extend it rather than adding a second one. Work through these steps in order. Skipping the tests or the empty state is the most common way a
feature ends up half-done.

## 1. Decide the shape

- What records exist and how they relate (`Question belongs_to :product`).
- Which half each screen belongs to (CLAUDE.md, "Two halves"). Most features have both: buyers
  ask questions on the site (`Products::QuestionsController`), the owner answers them in /admin
  (`Admin::QuestionsController`). Same models, separate controllers, views and tests.
- Who may see and change what: on the site, any visitor (buying never needs an account; a buyer
  reaches their order by its unguessable link), or, when the app has customer accounts, only the
  signed-in customer and only their own records; in /admin, all staff or only admins
  (`before_action :require_administrator`). Site pages must work with no accounts in the app.
- What a person does on each screen. Prefer fewer screens: index with inline actions over many pages.

Where the request leaves something open, choose what suits the owner best, build it, and list it
under Chosen in SPEC.md; don't stop to ask about what you can reasonably choose.

## 2. Model and migration

Generate, then edit by hand: `bin/rails generate model Question product:references name:string body:text answer:text status:string`.

- `null: false` on required columns, sensible defaults, indexes for foreign keys and anything you
  filter or sort by.
- Statuses are string enums: `enum :status, %w[ pending answered hidden ].index_by(&:itself), default: "pending"`.
- Money is integer cents with `money_attribute` (CLAUDE.md, "The shop").
- Validations for every rule the owner mentioned. Business logic lives in the model, not the controller.
- Add `scope :ordered` (or a better-named scope) for the default sort.
- Migrations must stay backward compatible (see CLAUDE.md).
- The other side of an association with a shop model (`Product has_many :questions`) goes in that
  model's extension, `app/models/product/extension.rb` (CLAUDE.md, "The shop"), never in the core.

## 3. Controller

Plain RESTful actions only; add a new controller rather than custom actions
(`Admin::Orders::ShipmentsController#create`, not `Admin::OrdersController#ship`).

The owner's side, in `app/controllers/admin/`:

```ruby
class Admin::QuestionsController < Admin::BaseController
  before_action :set_question, only: %i[ update destroy ]

  def index
    @page = paginate(Question.ordered.includes(:product), per: 50)
  end

  def update
    @question.update!(params.expect(question: [ :answer, :status ]))
    redirect_to admin_questions_path, notice: "Question updated.", status: :see_other
  end

  def destroy
    @question.destroy!
    redirect_to admin_questions_path, notice: "Question deleted.", status: :see_other
  end

  private
    def set_question
      @question = Question.find(params[:id])
    end
end
```

The site's side, in `app/controllers/`. Public pages show only what visitors may see, and find
products by slug the way `ProductsController` does:

```ruby
class Products::QuestionsController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: :create

  def create
    @product = Product.visible.find_by!(slug: params[:product_id])
    @question = @product.questions.new(params.expect(question: [ :name, :body ]))

    if @question.save
      redirect_to product_path(@product), notice: "Thanks! Your question shows here once it's answered."
    else
      redirect_to product_path(@product), alert: @question.errors.full_messages.to_sentence
    end
  end
end
```

A buyer's own records (an order, a download) are found by an unguessable token, never by id
(`Order.find_by!(token: params[:id])`); with customer accounts on, through `Current.customer`.

## 4. Views

Site pages follow DESIGN.md (`design` skill). /admin screens (`app/views/admin/questions/`) use the
UI kit (`ui-kit` skill). Every index needs an empty state; every form shows errors.

```erb
<%# app/views/admin/questions/index.html.erb %>
<%= page_header "Questions", "Answer questions to show them on product pages." %>

<% if @page.records.any? %>
  <%= card padded: false do %>
    <ul class="divide-y divide-line">
      <%= render partial: "admin/questions/question", collection: @page.records %>
    </ul>
  <% end %>
  <%= render "ui/pagination", page: @page %>
<% else %>
  <%= empty_state "No questions yet", "Questions visitors ask show up here." %>
<% end %>
```

```erb
<%# app/views/products/_question_form.html.erb, on the product page %>
<%= form_with model: [ product, Question.new ], url: product_questions_path(product), class: "space-y-4" do |form| %>
  <%= form.field :name, required: true %>
  <%= form.field :body, :text_area, rows: 3, required: true %>
  <%= form.submit "Ask" %>
<% end %>
```

`form.field` takes the input method name as its second argument; for `select` and `collection_select`
write the `label` and input separately inside `<div class="space-y-1.5">`.

## 5. Routes and navigation

- Site routes at the top of `config/routes.rb`, nested where they belong:

  ```ruby
  resources :products, only: %i[ index show ] do
    resources :questions, only: :create, module: :products
  end
  ```

  Admin routes inside `namespace :admin` (`resources :questions, only: %i[ index update destroy ]`).
- `<%= nav_link_to "Questions", admin_questions_path, match: "/admin/questions" %>` in
  `app/views/layouts/admin/_navigation.html.erb`. `match:` keeps the link active on the nested pages.
  Wrap groups of links in `nav_section` once the sidebar has more than a handful.
- Site links go in the site header (`app/views/layouts/site/_header.html.erb`) or on the pages.
- If this is now the site's main page, point `root` at it; the admin dashboard is `admin/root`.

## 6. Tests

- `test/models/question_test.rb`: each validation and business rule.
- `test/controllers/admin/questions_controller_test.rb`: every action, signed in via
  `sign_in_as users(:staff)`, plus the access rules (signed out goes to sign in; a signed-in customer
  is not let in; admin-only stays admin-only).
- `test/controllers/products/questions_controller_test.rb` (and the other site controllers): as a
  visitor with no accounts at all; a buyer's own records open by their token and not by their id. With customer accounts
  on (`setup { enable_customer_accounts }`), also as a customer via
  `sign_in_as_customer customers(:casey)`, who never sees `customers(:jordan)`'s records (404).
- Fixtures in `test/fixtures/questions.yml` that reference the shop's fixtures: `products(:tee)`,
  `products(:mug)`, `variants(:tee_black_s)`, `orders(:pending)`, `users(:owner)`, `users(:staff)`.
- `test/system/<flow>_test.rb`: a system test for each main flow, walked through in the browser the way
  people do it, from the page they start on to the result they expect. For questions: a visitor
  opens a product on a phone (`on_phone { … }`), asks a question, sees the thank-you; then the owner
  signs in to /admin (`sign_in_as users(:owner)`), answers it, and it shows on the product page.
  `test/system/shopping_test.rb` walks the built-in buying flow; keep it passing. Also one
  mistake (a missing field shows its error). Use `click_on`, `fill_in`, `select`, `assert_text` with the
  words on screen. JavaScript errors fail these tests, so Stimulus code gets exercised too.

Run `bin/rails test`, `bin/rails test:system` and `bin/rubocop`, then `bin/rails tailwindcss:build`.

## 7. Try it

Look at what you built in the running app, the way its users will: `bin/look` with the pages you
added or changed, as a visitor for site pages (`bin/look /products/cat-mom-tee`), as a customer for their pages when the app has
customer accounts (`bin/look /account --as customer`), and signed in to /admin for staff pages
(`bin/look /admin/questions --as owner`). It reports error pages, JavaScript errors, broken images and links,
and pages wider than a phone, and saves screenshots at phone and desktop width: Read them. Check the
empty state and a page with a few records (add them in `db/seeds.rb` and run `bin/rails db:seed` when
the app has none). Fix everything it finds and anything that looks wrong, then look again.

## 8. Summary for the owner

Tick what's done under Asked in SPEC.md first (CLAUDE.md). Then tell them what they can do now and
where to find it, in their language, and the choices they may want to change. Mention anything that changes existing
data or needs their action (for example, settings to fill in).
