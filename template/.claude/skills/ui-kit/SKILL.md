---
name: ui-kit
description: Reference for the building blocks of the owner's and staff's screens (shells, page header, card, stat, empty state, badge, alert, tabs, dialog, menu, buttons, forms, navigation, icons) with copy-paste examples. Use when writing those screens or any form. For the app's look and customer-facing pages, use the design skill.
---

# UI kit

Building blocks for the screens the owner and staff work in (records, schedules, reports, settings),
so those screens stay consistent as the app grows. They follow the theme, so they wear the app's
look. Customer-facing pages are designed freely instead (`design` skill), though they can use these
blocks where they fit, and every form uses the form builder. Helpers live in `app/helpers/ui_helper.rb`,
partials in `app/views/ui/`, the form builder in `app/form_builders/ui_form_builder.rb`.

On owner screens, compose from these blocks and use Tailwind mostly for layout: grid, flex, spacing,
widths. Colors, type and corners come from the theme.

## Theme

`app/assets/tailwind/application.css` sets the look (choosing it is in the `design` skill). Editing
it rebrands every screen: the brand scale, `accent`, `canvas`, `surface`, `ink`, `muted`, `line`,
`radius-lg`, `radius-xl`, `font-display`, `font-sans`. Fonts come from `fonts.css`; don't call an
external font service.

In views, use those names: `bg-canvas`, `bg-surface`, `bg-surface-muted`, `text-ink`, `text-muted`,
`border-line`, `divide-line`, `brand-*`. Green, yellow and red are for status only.

After a theme or view change, run `bin/rails tailwindcss:build`.

## Shells

- **application** (default). Sidebar for navigation, top bar for the account, content scrolls in
  the main pane. For the owner's and staff's screens.
- **public**. The customer-facing site: home, catalog, menu, booking. In the controller:
  `layout "public"`. Its header and footer are partials in `app/views/layouts/public/` to redesign
  per app; the yield is full-bleed. Pages can add header links:

```erb
<% content_for :public_nav do %>
  <%= bar_link_to "Menu", menu_path %>
<% end %>
```

- **authentication**. Centered card. Already used by sign in, and not for product screens.

Add a top-level screen in `app/views/layouts/_navigation.html.erb`:

```erb
<%= nav_link_to "Customers", customers_path, match: "/customers" %>
```

`match:` keeps the link active on show and edit. Leave it off for an exact match (the home link).

When the sidebar has more than a handful of links, group them:

```erb
<%= nav_section "Shop" do %>
  <%= nav_link_to "Orders", orders_path, match: "/orders" %>
  <%= nav_link_to "Products", products_path, match: "/products" %>
<% end %>
```

## Icons

`icon "calendar-check"` draws a Lucide icon in the current text color; `size:` (20), `stroke:` (2) and
`class:` are optional. Find names with `bin/icons <word>`.

```erb
<%= link_to new_appointment_path, class: button_classes do %><%= icon "plus", size: 16 %> New appointment<% end %>
```

## Page header

Sets the page `<title>` too. Actions and breadcrumbs are optional.

```erb
<%= page_header "Customers", "Everyone who has booked with you.",
      breadcrumbs: [["Customers", customers_path]] do %>
  <%= link_to "Add customer", new_customer_path, class: button_classes %>
<% end %>
```

## Buttons, links, toolbar

`button_classes(variant, size: :md)` with `:primary` (default), `:secondary`, `:danger`, `:ghost`.
`size: :sm` is for a dense toolbar, not the main action. One primary button per area.
Destructive actions always confirm. `form.submit` is already primary. `link_classes` is the text link.

```erb
<%= toolbar do %>
  <%= link_to "Add customer", new_customer_path, class: button_classes %>
  <div class="flex gap-2">
    <%= link_to "Export", customers_path(format: :csv), class: button_classes(:secondary, size: :sm) %>
  </div>
<% end %>

<%= link_to "Edit", edit_customer_path(customer), class: button_classes(:secondary) %>
<%= link_to "View", customer_path(customer), class: link_classes %>
<%= button_to "Delete", customer, method: :delete, class: button_classes(:danger),
      form: { data: { turbo_confirm: "Delete #{customer.name}?" } } %>
```

## Card, stat, empty state

```erb
<div class="grid gap-4 sm:grid-cols-3">
  <%= stat @visits.size, "Visits this week", hint: "Booked and completed" %>
</div>

<%= card do %>
  <h2 class="text-sm font-semibold text-ink">Details</h2>
<% end %>

<%= card padded: false do %>
  <ul class="divide-y divide-line">
    <li class="flex items-center justify-between gap-4 px-6 py-4">...</li>
  </ul>
<% end %>

<%= empty_state "No customers yet", "They'll appear here after their first booking." do %>
  <%= link_to "Add a customer", new_customer_path, class: button_classes %>
<% end %>
```

Every list needs an empty state. Put a person next to their name with `avatar(user.name)`.

## Badge and alert

Badge tones: `:gray` (default), `:brand`, `:green`, `:yellow`, `:red`.
Alert tones: `:info` (default), `:success`, `:warning`, `:danger`. Flash (`notice:` / `alert:`)
already renders; `alert` is for guidance that is part of the page.

```erb
<%= badge appointment.status.humanize, tone: { "confirmed" => :green, "cancelled" => :red }.fetch(appointment.status, :gray) %>
<%= alert "This week is fully booked.", tone: :warning %>
```

## Tabs and description list

Tabs are links, so each tab is a real page.

```erb
<%= tabs do %>
  <%= tab_to "Upcoming", appointments_path %>
  <%= tab_to "Past", past_appointments_path %>
<% end %>

<%= card do %>
  <%= description_list [
        ["Phone", customer.phone],
        ["Plan", badge(customer.plan.humanize, tone: :brand)]
      ] %>
<% end %>
```

## Tables

```erb
<%= card padded: false do %>
  <div class="overflow-x-auto">
    <table class="min-w-full divide-y divide-line text-sm">
      <thead class="bg-surface-muted text-left text-muted">
        <tr><th class="px-6 py-3 font-medium">Name</th><th class="px-6 py-3 font-medium">Phone</th></tr>
      </thead>
      <tbody class="divide-y divide-line">
        <% @customers.each do |customer| %>
          <tr>
            <td class="px-6 py-4 font-medium text-ink"><%= customer.name %></td>
            <td class="px-6 py-4 text-muted"><%= customer.phone %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
<% end %>
```

## Forms

Every `form_with` uses `UiFormBuilder`. Inputs are styled. Pass `class:` only for layout (`w-full`).

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

## Dialog and menu

A dialog is for a short confirm or a small form that doesn't deserve its own page.
A menu is a short list of row actions.

```erb
<%= dialog_button "New note", "new-note" %>
<%= dialog id: "new-note", title: "New note" do %>
  <%= form_with model: @note, class: "space-y-4" do |form| %>
    <%= form.field :body, :text_area, rows: 3 %>
    <%= form.submit %>
  <% end %>
<% end %>

<%= menu "Actions" do %>
  <%= menu_link_to "Edit", edit_customer_path(customer) %>
  <%= menu_button_to "Delete", customer_path(customer), method: :delete,
        class: "text-red-700 hover:bg-red-50",
        form: { data: { turbo_confirm: "Delete #{customer.name}?" } } %>
<% end %>
```

## Adding a block

When the same arrangement shows up on a second screen, add a method to `UiHelper` and a partial in
`app/views/ui/`, built from theme colors. Mention it in this skill. Don't copy a chunk of markup
from screen to screen. Styles of the app's own design go at the end of application.css, not in a
second stylesheet.

## Layout, type, phones

- On owner screens body text is `text-sm`. Secondary text is `text-muted`. Headings are `font-semibold text-ink`.
  Page titles come from `page_header`.
- `space-y-4` in forms, `gap-2` between buttons, `mb-6` between page sections.
- Everything works on a phone: the sidebar collapses behind Menu, tables sit in `overflow-x-auto`,
  actions use `flex-wrap`. Don't use a fixed pixel width for a page.
- Live updates use Turbo Streams (`broadcasts_refreshes` on the model, `turbo_stream_from` in the view).
