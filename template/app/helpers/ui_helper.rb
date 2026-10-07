# Building blocks for the owner's and staff's screens, so they stay consistent as
# the app grows; customer-facing pages are designed freely (design skill). Partials
# live in app/views/ui.
# Looks come from the theme in app/assets/tailwind/application.css.
module UiHelper
  FIELD_CLASSES = "block w-full rounded-lg border border-line bg-surface px-3 py-2 text-sm text-ink shadow-xs placeholder:text-muted focus:border-brand-500 focus:outline-2 focus:outline-brand-500/20"

  BUTTON_BASE = "inline-flex items-center justify-center gap-2 rounded-lg font-semibold transition cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-2 disabled:opacity-50"
  BUTTON_SIZES = {
    sm: "px-2.5 py-1.5 text-xs",
    md: "px-3.5 py-2 text-sm"
  }
  BUTTON_VARIANTS = {
    primary: "bg-brand-600 text-white shadow-xs hover:bg-brand-500 focus-visible:outline-brand-600",
    secondary: "bg-surface text-ink shadow-xs ring-1 ring-inset ring-line hover:bg-surface-muted",
    danger: "bg-red-600 text-white shadow-xs hover:bg-red-500 focus-visible:outline-red-600",
    ghost: "text-ink hover:bg-surface-muted"
  }

  BADGE_TONES = {
    gray: "bg-surface-muted text-ink",
    brand: "bg-brand-50 text-brand-800",
    green: "bg-green-50 text-green-700",
    yellow: "bg-yellow-50 text-yellow-800",
    red: "bg-red-50 text-red-700"
  }

  ALERT_TONES = {
    info: "border-brand-200 bg-brand-50 text-brand-800",
    success: "border-green-200 bg-green-50 text-green-800",
    warning: "border-yellow-200 bg-yellow-50 text-yellow-900",
    danger: "border-red-200 bg-red-50 text-red-700"
  }

  LINK_CLASSES = "font-medium text-brand-700 hover:text-brand-600"
  MENU_ITEM_CLASSES = "block w-full rounded-md px-3 py-2 text-left text-sm text-ink hover:bg-surface-muted"

  # Any Lucide icon (https://lucide.dev), drawn in the current text color:
  # icon "calendar-check", size: 18, class: "text-brand-600". Find names with bin/icons.
  def icon(name, size: 20, stroke: 2, **options)
    paths = UiHelper.icons.fetch(name.to_s) { raise ArgumentError, "No icon named #{name.inspect}. Search with: bin/icons #{name}" }
    options[:class] = class_names("shrink-0", options[:class])
    tag.svg(paths.html_safe, xmlns: "http://www.w3.org/2000/svg", width: size, height: size, viewBox: "0 0 24 24", fill: "none",
      stroke: "currentColor", "stroke-width": stroke, "stroke-linecap": "round", "stroke-linejoin": "round", "aria-hidden": true, **options)
  end

  def self.icons
    @icons ||= JSON.parse(Rails.root.join("vendor/icons/lucide.json").read)
  end

  # For link_to and button_to: link_to "New", new_thing_path, class: button_classes(:secondary)
  # size is :md (default) or :sm for dense toolbars.
  def button_classes(variant = :primary, size: :md)
    [ BUTTON_BASE, BUTTON_SIZES.fetch(size), BUTTON_VARIANTS.fetch(variant) ].join(" ")
  end

  def link_classes
    LINK_CLASSES
  end

  # Same look as form fields, for a rare input that is not inside form_with.
  def field_classes
    FIELD_CLASSES
  end

  def badge(text, tone: :gray)
    tag.span(text, class: "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium #{BADGE_TONES.fetch(tone)}")
  end

  # Inline notice. Tones: :info (default), :success, :warning, :danger.
  def alert(message = nil, tone: :info, **options, &block)
    options[:class] = class_names("rounded-lg border px-4 py-3 text-sm", ALERT_TONES.fetch(tone), options[:class])
    options[:role] ||= "status"
    tag.div(block ? capture(&block) : message, **options)
  end

  # Panel. Pass class: to add layout, not a new color.
  def card(padded: true, **options, &block)
    options[:class] = class_names("rounded-xl border border-line bg-surface shadow-xs", options[:class], "p-6" => padded)
    tag.div(**options, &block)
  end

  # Page title with optional description, breadcrumbs and actions; also sets <title>.
  # breadcrumbs: [["Customers", customers_path], ["Ada", nil]]
  def page_header(title, description = nil, breadcrumbs: nil, &actions)
    content_for :title, title
    render "ui/page_header", title: title, description: description, breadcrumbs: breadcrumbs,
      actions: (capture(&actions) if actions)
  end

  # Shown when a list has nothing in it yet, with an optional call to action.
  def empty_state(title, description = nil, &action)
    render "ui/empty_state", title: title, description: description, action: (capture(&action) if action)
  end

  def stat(value, label, hint: nil)
    render "ui/stat", value: value, label: label, hint: hint
  end

  # Rows are [label, value] pairs. Values can be text or HTML from a helper.
  def description_list(rows)
    render "ui/description_list", rows: rows
  end

  def avatar(name, size: :md)
    initials = name.to_s.split.first(2).filter_map { |part| part[0] }.join.upcase
    initials = "?" if initials.empty?
    sizes = { sm: "size-7 text-xs", md: "size-9 text-sm" }
    tag.span(initials, class: "inline-flex shrink-0 items-center justify-center rounded-full bg-brand-50 font-semibold text-brand-800 #{sizes.fetch(size)}", aria: { hidden: true })
  end

  # Sidebar link. match: "/customers" stays active on nested pages. Exact match is the default,
  # so the root link does not light up on every screen.
  def nav_link_to(name, path, match: nil)
    active = match.present? ? request.path.start_with?(match.to_s) : current_page?(path)
    link_to name, path, aria: { current: ("page" if active) }, class: class_names(
      "block rounded-lg px-3 py-2 text-sm font-medium",
      active ? "bg-brand-50 text-brand-800" : "text-muted hover:bg-surface-muted hover:text-ink"
    )
  end

  # Group of sidebar links. Use once a product has more than a handful of screens.
  def nav_section(title, &block)
    render "ui/nav_section", title: title, body: capture(&block)
  end

  # Horizontal link for the public layout header.
  def bar_link_to(name, path)
    active = current_page?(path)
    link_to name, path, aria: { current: ("page" if active) }, class: class_names(
      "rounded-lg px-3 py-1.5 text-sm font-medium whitespace-nowrap",
      active ? "bg-surface-muted text-ink" : "text-muted hover:text-ink"
    )
  end

  def tabs(&block)
    tag.div(class: "-mx-1 mb-6 flex gap-1 overflow-x-auto border-b border-line", &block)
  end

  def tab_to(name, path)
    active = current_page?(path)
    link_to name, path, class: class_names(
      "shrink-0 border-b-2 px-3 py-2 text-sm font-medium",
      active ? "border-brand-600 text-brand-700" : "border-transparent text-muted hover:text-ink"
    )
  end

  # Row of filters or secondary actions under a page header.
  def toolbar(&block)
    tag.div(class: "mb-4 flex flex-wrap items-center justify-between gap-3", &block)
  end

  def dialog(id:, title: nil, &block)
    render "ui/dialog", id: id, title: title, body: capture(&block)
  end

  def dialog_button(label, dialog, variant: :secondary, **options)
    options[:type] = "button"
    options[:class] = class_names(button_classes(variant), options[:class])
    options[:data] = (options[:data] || {}).merge(
      controller: "dialog-trigger",
      dialog_trigger_id_value: dialog,
      action: "dialog-trigger#open"
    )
    button_tag(label, options)
  end

  def menu(label, **options, &block)
    render "ui/menu", label: label, button_class: options[:class], items: capture(&block)
  end

  def menu_link_to(name, path, **options)
    options[:class] = class_names(MENU_ITEM_CLASSES, options[:class])
    options[:role] ||= "menuitem"
    link_to(name, path, **options)
  end

  def menu_button_to(name, path, **options)
    options[:class] = class_names(MENU_ITEM_CLASSES, options[:class])
    options[:form] = { class: "block" }.merge(options[:form] || {})
    button_to(name, path, **options)
  end
end
