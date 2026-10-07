# The part of a preview page the owner pointed at (the template's preview probe sends
# where it is), so the agent knows which "this" their message is about.
class PointedElement
  LIMITS = { "page" => 300, "selector" => 500, "tag" => 40, "text" => 200, "html" => 800 }

  # From the composer's hidden field; nothing when it's empty or not what the probe sends.
  def self.from_param(json)
    data = JSON.parse(json.to_s)
    return unless data.is_a?(Hash) && data["selector"].is_a?(String) && data["selector"].present?

    new(LIMITS.to_h { |key, limit| [ key, data[key].to_s.truncate(limit) ] })
  rescue JSON::ParserError
    nil
  end

  attr_reader :data

  def initialize(data)
    @data = data
  end

  def page = data["page"]
  def text = data["text"]

  # How it shows in the chat: its text, or the kind of element.
  def label
    text.presence || "<#{data["tag"]}>"
  end

  def to_prompt
    [ "The owner pointed at this part of the page #{page.presence || "/"} in the preview; their message is about it.",
      "- Element: <#{data["tag"]}>, CSS selector: #{data["selector"]}",
      ("- Text: “#{text}”" if text.present?),
      "- HTML:\n```html\n#{data["html"]}\n```" ].compact.join("\n")
  end
end
