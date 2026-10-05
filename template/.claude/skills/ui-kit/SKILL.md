---
name: ui-kit
description: Reference for this app's UI building blocks (page header, card, empty state, badge, buttons, styled forms, navigation, flash) with copy-paste examples. Use when writing or changing any view.
---

# UI kit

Helpers live in `app/helpers/ui_helper.rb`, partials in `app/views/ui/`, the form builder in
`app/form_builders/ui_form_builder.rb`. Compose screens from these; reach for raw Tailwind only for
layout (grid, flex, spacing, widths).

## Page header

Sets the page `<title>` too. Actions are optional.

```erb
<%= page_header "Customers", "Everyone who has booked with you." do %>
  <%= link_to "Add customer", new_customer_path, class: button_classes %>
<% end %>
```

## Buttons

`button_classes(variant)` with `:primary` (default), `:secondary`, `:danger`, `:ghost`.
Use it on `link_to`, `button_to`, and plain `<button>`; `form.submit` is already primary.

```erb
<%= link_to "Edit", edit_customer_path(customer), class: button_classes(:secondary) %>
<%= button_to "Delete", customer, method: :delete, class: button_classes(:danger),
      form: { data: { turbo_confirm: "Delete #{customer.name}?" } } %>
```

One primary button per screen area. Destructive actions always confirm.

## Card

White panel. `padded: false` when the content (like a list) brings its own padding.

```erb
<%= card do %>
  <h2 class="text-sm font-semibold text-gray-900">Details</h2>
  ...
<% end %>

<%= card padded: false do %>
  <ul class="divide-y divide-gray-100">
    <li class="flex items-center justify-between px-6 py-4">...</li>
  </ul>
<% end %>
```

## Empty state

Every list needs one.

```erb
<%= empty_state "No customers yet", "They'll appear here after their first booking." do %>
  <%= link_to "Add a customer", new_customer_path, class: button_classes %>
<% end %>
```

## Badge

Tones: `:gray` (default), `:brand`, `:green`, `:yellow`, `:red`.

```erb
<%= badge appointment.status.humanize, tone: { "confirmed" => :green, "cancelled" => :red }.fetch(appointment.status, :gray) %>
```

## Forms

Every `form_with` uses `UiFormBuilder`, so inputs are styled and show errors automatically.

```erb
<%= form_with model: customer, class: "space-y-4" do |form| %>
  <%= form.errors %>
  <%= form.field :name, required: true, autofocus: true %>
  <%= form.field :email, :email_field, hint: "For booking confirmations." %>
  <%= form.field :phone, :telephone_field %>
  <%= form.field :notes, :text_area, rows: 4 %>

  <div class="space-y-1.5">
    <%= form.label :plan %>
    <%= form.select :plan, Customer.plans.keys.map { |plan| [ plan.humanize, plan ] } %>
  </div>

  <div class="flex items-center gap-2 pt-2">
    <%= form.submit %>
    <%= link_to "Cancel", customers_path, class: button_classes(:ghost) %>
  </div>
<% end %>
```

Put forms in a narrow column: `<div class="max-w-lg"><%= card { render "form", customer: @customer } %></div>`.

## Tables

For data with several columns, use a table inside an unpadded card:

```erb
<%= card padded: false do %>
  <div class="overflow-x-auto">
    <table class="min-w-full divide-y divide-gray-200 text-sm">
      <thead class="bg-gray-50 text-left text-xs font-medium uppercase tracking-wide text-gray-500">
        <tr><th class="px-6 py-3">Name</th><th class="px-6 py-3">Phone</th></tr>
      </thead>
      <tbody class="divide-y divide-gray-100">
        <% @customers.each do |customer| %>
          <tr><td class="px-6 py-4 font-medium text-gray-900"><%= customer.name %></td><td class="px-6 py-4 text-gray-500"><%= customer.phone %></td></tr>
        <% end %>
      </tbody>
    </table>
  </div>
<% end %>
```

## Navigation and flash

- Top-level screens: `nav_link_to "Customers", customers_path` in `app/views/layouts/_navigation.html.erb`.
- Flash messages render automatically; set them with `redirect_to ..., notice: "Saved."` or `alert:`.

## Look and feel

- Colors: `brand-*` for emphasis and links, `gray-*` for text and borders, `red/green/yellow` only for status.
- Text: `text-sm` body, `text-gray-500` secondary, `font-semibold` headings. Page titles come from `page_header`.
- Spacing: `space-y-4` in forms, `gap-2` between buttons, `mb-6` between page sections.
- Everything must work on a phone: use `flex-wrap`, `overflow-x-auto` for tables, and avoid fixed widths.
- Live updates use Turbo Streams (`broadcasts_refreshes` on the model, `turbo_stream_from` in the view).
