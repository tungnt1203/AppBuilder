# Building blocks for every screen. Prefer these over hand-written Tailwind so
# the app looks consistent. Partials live in app/views/ui.
module UiHelper
  BUTTON_BASE = "inline-flex items-center justify-center gap-2 rounded-lg px-3.5 py-2 text-sm font-semibold transition cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-2 disabled:opacity-50"
  BUTTON_VARIANTS = {
    primary: "bg-brand-600 text-white shadow-xs hover:bg-brand-500 focus-visible:outline-brand-600",
    secondary: "bg-white text-gray-900 shadow-xs ring-1 ring-inset ring-gray-300 hover:bg-gray-50",
    danger: "bg-red-600 text-white shadow-xs hover:bg-red-500 focus-visible:outline-red-600",
    ghost: "text-gray-700 hover:bg-gray-100"
  }

  BADGE_TONES = {
    gray: "bg-gray-100 text-gray-700",
    brand: "bg-brand-50 text-brand-700",
    green: "bg-green-50 text-green-700",
    yellow: "bg-yellow-50 text-yellow-800",
    red: "bg-red-50 text-red-700"
  }

  # For link_to and button_to: link_to "New", new_thing_path, class: button_classes(:secondary)
  def button_classes(variant = :primary)
    [ BUTTON_BASE, BUTTON_VARIANTS.fetch(variant) ].join(" ")
  end

  def badge(text, tone: :gray)
    tag.span(text, class: "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium #{BADGE_TONES.fetch(tone)}")
  end

  # White panel for grouping content: <%= card do %> ... <% end %>
  def card(padded: true, **options, &block)
    tag.div(**options, class: class_names("rounded-xl border border-gray-200 bg-white shadow-xs", "p-6" => padded), &block)
  end

  # Page title with optional description and action buttons; also sets <title>.
  def page_header(title, description = nil, &actions)
    content_for :title, title
    render "ui/page_header", title: title, description: description, actions: (capture(&actions) if actions)
  end

  # Shown when a list has nothing in it yet, with an optional call to action.
  def empty_state(title, description = nil, &action)
    render "ui/empty_state", title: title, description: description, action: (capture(&action) if action)
  end

  def nav_link_to(name, path)
    link_to name, path, class: class_names("rounded-md px-3 py-1.5 font-medium whitespace-nowrap",
      current_page?(path) ? "bg-gray-100 text-gray-900" : "text-gray-600 hover:text-gray-900")
  end
end
