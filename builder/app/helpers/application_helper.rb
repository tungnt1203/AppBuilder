module ApplicationHelper
  STATUS_LABELS = { "setting_up" => "Setting up", "ready" => "Ready", "working" => "Working", "failed" => "Needs attention" }

  ICONS = {
    back: [ "M15 18l-6-6 6-6" ],
    reload: [ "M21 12a9 9 0 1 1-2.64-6.36L21 8", "M21 3v5h-5" ],
    external: [ "M14 4h6v6", "M20 4l-9 9", "M19 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1h5" ],
    send: [ "M12 19V5", "M5 12l7-7 7 7" ],
    chevron: [ "M9 6l6 6-6 6" ],
    steps: [ "M4 6h16", "M4 12h10", "M4 18h7" ],
    history: [ "M3 12a9 9 0 1 0 3-6.7L3 8", "M3 3v5h5", "M12 7v5l3 2" ],
    check: [ "M5 12l5 5L20 7" ],
    alert: [ "M12 9v4", "M12 17h.01", "M10.3 3.9 2.4 18a2 2 0 0 0 1.7 3h15.8a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z" ],
    more: [ "M5 11a1 1 0 1 0 0 2 1 1 0 1 0 0-2z", "M12 11a1 1 0 1 0 0 2 1 1 0 1 0 0-2z", "M19 11a1 1 0 1 0 0 2 1 1 0 1 0 0-2z" ],
    pencil: [ "M12 20h9", "M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z" ],
    copy: [ "M9 8h10a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1z", "M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3" ],
    trash: [ "M3 6h18", "M8 6V4h8v2", "M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6", "M10 11v6", "M14 11v6" ],
    monitor: [ "M3 5a1 1 0 0 1 1-1h16a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z", "M8 20h8", "M12 16v4" ],
    tablet: [ "M6 3h12a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z", "M11 17.5h2" ],
    phone: [ "M8.5 3h7a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1h-7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z", "M11 17.5h2" ],
    expand: [ "M15 3h6v6", "M9 21H3v-6", "M21 3l-7 7", "M3 21l7-7" ],
    shrink: [ "M4 14h6v6", "M20 10h-6V4", "M14 10l7-7", "M3 21l7-7" ],
    eye: [ "M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z", "M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z" ],
    eye_off: [ "M3 3l18 18", "M10.6 6.1A9.8 9.8 0 0 1 12 6c6.5 0 10 6 10 6a17 17 0 0 1-3.2 3.9", "M6.6 6.6C3.9 8.3 2 12 2 12s3.5 6 10 6a9.6 9.6 0 0 0 4.4-1", "M9.9 9.9a3 3 0 0 0 4.2 4.2" ]
  }

  def icon(name, size: 16)
    tag.svg(width: size, height: size, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": 2,
            "stroke-linecap": "round", "stroke-linejoin": "round", "aria-hidden": true, class: "shrink-0 #{name == :chevron ? "chevron" : ""}") do
      safe_join(ICONS.fetch(name).map { |d| tag.path(d: d) })
    end
  end

  # Asks the agent to fix what the preview check found.
  def fix_request(project)
    "The preview shows an error:\n\n#{project.preview_error}\n\nPlease find the cause and fix it."
  end

  def status_label(project)
    if project.ready? && project.preview_broken?
      tag.span("Preview has a problem", class: "status status-failed")
    else
      tag.span(STATUS_LABELS.fetch(project.status), class: "status status-#{project.status}")
    end
  end

  def markdown(text)
    renderer = Redcarpet::Render::HTML.new(filter_html: true, no_images: true, safe_links_only: true, link_attributes: { target: "_blank" })
    Redcarpet::Markdown.new(renderer, autolink: true, tables: true, fenced_code_blocks: true, strikethrough: true, lax_spacing: true).render(text.to_s).html_safe
  end

  # Consecutive agent actions collapse into one group so the chat reads as a conversation.
  def chat_items(messages)
    messages.chunk_while { |a, b| a.action? && b.action? }.map { |group| group.first.action? ? group : group.first }
  end

  def steps_summary(actions)
    counts = actions.group_by { |action| action.data["tool"] }.transform_values(&:size)
    changed = counts.fetch("Write", 0) + counts.fetch("Edit", 0)
    looked = counts.fetch("Read", 0) + counts.fetch("Grep", 0) + counts.fetch("Glob", 0)
    parts = []
    thought = actions.sum { |action| action.data["seconds"].to_i }
    parts << "thought for #{duration_in_words(thought)}" if thought.positive?
    parts << "looked at #{pluralize(looked, "file")}" if looked.positive?
    parts << "changed #{pluralize(changed, "file")}" if changed.positive?
    parts << "ran #{pluralize(counts["Bash"], "command")}" if counts["Bash"]
    parts.to_sentence.upcase_first.presence || pluralize(actions.size, "step")
  end

  def duration_in_words(seconds)
    seconds < 60 ? pluralize(seconds, "second") : pluralize((seconds / 60.0).round, "minute")
  end

  def plan_progress(tasks)
    "#{tasks.count { |task| task["status"] == "completed" }} of #{tasks.size} done"
  end

  def turn_summary(message)
    data = message.data
    duration = distance_of_time_in_words(data["duration_ms"] / 1000.0) if data["duration_ms"]
    cost = number_to_currency(data["total_cost_usd"], precision: 2) if data["total_cost_usd"]
    [ ("Finished in #{duration}" if duration), (pluralize(data["num_turns"], "step") if data["num_turns"]), cost ].compact.join(", ")
  end
end
