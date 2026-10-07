---
name: new-feature
description: Add a new screen or resource (model, migration, controller, views, navigation, tests) to this app the conventional way. Use whenever the owner asks for something the app should track or show, like "appointments", "customers", "a booking page".
---

# Adding a feature

Work through these steps in order. Skipping the tests or the empty state is the most common way a
feature ends up half-done.

## 1. Decide the shape

- What records exist and how they relate (`Appointment belongs_to :customer`).
- Who may see and change them: the public (customers, visitors), everyone signed in, only the
  record's creator, or only admins. Public screens use `allow_unauthenticated_access` and must work
  with no accounts in the app (see "Public pages and sign in" in CLAUDE.md).
- What a person does on each screen. Prefer fewer screens: index with inline actions over many pages.

If the request is ambiguous, pick the simplest reasonable interpretation and say so in your summary.

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
(`Appointments::CancellationsController#create`, not `AppointmentsController#cancel`).

```ruby
class AppointmentsController < ApplicationController
  before_action :set_appointment, only: %i[ show edit update destroy ]

  def index
    @appointments = Appointment.ordered.includes(:customer)
  end

  def new
    @appointment = Appointment.new
  end

  def create
    @appointment = Appointment.new(appointment_params)

    if @appointment.save
      redirect_to appointments_path, notice: "Appointment booked."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # show, edit, update, destroy follow the same pattern.
  # destroy redirects with status: :see_other.

  private
    def set_appointment
      @appointment = Appointment.find(params[:id])
    end

    def appointment_params
      params.expect(appointment: [ :customer_id, :starts_at, :notes ])
    end
end
```

When members should only see their own records, scope every lookup through the owner:
`Current.user.appointments.find(params[:id])` instead of `Appointment.find`. Admin-only controllers
inherit from `Admin::BaseController`.

## 4. Views

Pages visitors use (catalog, menu, booking, the home page) use `layout "public"` and follow
DESIGN.md (`design` skill). The owner's and staff's screens stay on the application layout and use
the UI kit (`ui-kit` skill). Every index needs an empty state; every form shows errors.

```erb
<%= page_header "Appointments", "Upcoming visits." do %>
  <%= link_to "Book appointment", new_appointment_path, class: button_classes %>
<% end %>

<% if @appointments.any? %>
  <%= card padded: false do %>
    <ul class="divide-y divide-line">
      <%= render @appointments %>
    </ul>
  <% end %>
<% else %>
  <%= empty_state "No appointments yet", "Booked appointments show up here." do %>
    <%= link_to "Book the first one", new_appointment_path, class: button_classes %>
  <% end %>
<% end %>
```

```erb
<%# _form.html.erb %>
<%= form_with model: appointment, class: "space-y-4" do |form| %>
  <%= form.errors %>
  <div class="space-y-1.5">
    <%= form.label :customer_id, "Customer" %>
    <%= form.collection_select :customer_id, Customer.ordered, :id, :name, prompt: "Choose a customer" %>
  </div>
  <%= form.field :starts_at, :datetime_local_field, required: true %>
  <%= form.field :notes, :text_area, rows: 4 %>
  <%= form.submit %>
<% end %>
```

`form.field` takes the input method name as its second argument; for `select` and `collection_select`
write the `label` and input separately inside `<div class="space-y-1.5">`.

## 5. Routes and navigation

- `resources :appointments` in `config/routes.rb`.
- `<%= nav_link_to "Appointments", appointments_path, match: "/appointments" %>` in
  `app/views/layouts/_navigation.html.erb`. `match:` keeps the link active on the nested pages.
  Wrap groups of links in `nav_section` once the sidebar has more than a handful.
- If this is now the app's main screen, point `root` at it.

## 6. Tests

- `test/models/appointment_test.rb`: each validation and business rule.
- `test/controllers/appointments_controller_test.rb`: every action, signed in via `sign_in_as users(:member)`,
  plus the access rules (signed out redirects; members can't touch others' records; admin-only stays admin-only).
- Fixtures in `test/fixtures/appointments.yml` that reference `users(:owner)`, `users(:admin)`, `users(:member)`.
- `test/system/<flow>_test.rb`: a system test for each main flow, walked through in the browser the way
  people do it, from the page they start on to the result they expect. For a booking app: a visitor
  opens the booking page on a phone (`on_phone { … }`), picks a service and a time, submits, sees the
  confirmation; then the owner signs in (`sign_in_as users(:owner)`) and finds the booking. Also one
  mistake (a missing field shows its error). Use `click_on`, `fill_in`, `select`, `assert_text` with the
  words on screen. JavaScript errors fail these tests, so Stimulus code gets exercised too.

Run `bin/rails test`, `bin/rails test:system` and `bin/rubocop`, then `bin/rails tailwindcss:build`.

## 7. Try it

Look at what you built in the running app, the way its users will: `bin/look` with the pages you
added or changed, signed in for staff pages (`bin/look /appointments /appointments/new --as owner`),
and as a visitor for public ones. It reports error pages, JavaScript errors, broken images and links,
and pages wider than a phone, and saves screenshots at phone and desktop width: Read them. Check the
empty state and a page with a few records (add them in `db/seeds.rb` and run `bin/rails db:seed` when
the app has none). Fix everything it finds and anything that looks wrong, then look again.

## 8. Summary for the owner

What they can do now and where to find it, in their language. Mention anything that changes existing
data or needs their action (for example, settings to fill in).
