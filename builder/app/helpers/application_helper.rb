module ApplicationHelper
  STATUS_STYLES = {
    "setting_up" => [ "Setting up", "bg-yellow-50 text-yellow-800" ],
    "ready" => [ "Ready", "bg-green-50 text-green-700" ],
    "working" => [ "Working", "bg-indigo-50 text-indigo-700" ],
    "failed" => [ "Needs attention", "bg-red-50 text-red-700" ]
  }

  def status_badge(project)
    label, classes = STATUS_STYLES.fetch(project.status)
    tag.span(label, class: "inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium #{classes}")
  end

  def markdown(text)
    renderer = Redcarpet::Render::HTML.new(filter_html: true, no_images: true, safe_links_only: true, link_attributes: { target: "_blank" })
    Redcarpet::Markdown.new(renderer, autolink: true, tables: true, fenced_code_blocks: true, strikethrough: true).render(text.to_s).html_safe
  end

  def turn_summary(message)
    data = message.data
    [ "Done",
      ("#{data["num_turns"]} steps" if data["num_turns"]),
      (number_to_currency(data["total_cost_usd"], precision: 2) if data["total_cost_usd"]),
      (distance_of_time_in_words(data["duration_ms"] / 1000.0) if data["duration_ms"]) ].compact.join(" · ")
  end
end
