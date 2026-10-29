# The demo catalog in the shop's own world (DemoCatalog.add!(niche:)): from the owner's first
# request, the eight demo products' names, the words printed on them, their descriptions, three
# collection names and an accent color, so a cat shop's preview shows cat tees, not stickers that
# say "Good vibes". Asked of Claude once, in the setup job; nil when nothing usable came back in
# time, and the static demo stays.
class DemoCatalog::Niche
  TIMEOUT = 60 # seconds
  MODEL = "sonnet"
  ROLES = %w[ tee sale_tee hoodie sweatshirt mug poster tote stickers ].freeze

  def self.for(request) = request.present? ? new(request).spec : nil

  def initialize(request)
    @request = request.to_s
  end

  # { "products" => { "tee" => { "title", "phrase", "description" }, …, "stickers" => { …, "phrases" => [ 3 ] } },
  #   "collections" => [ 3 names ], "accent" => "#rrggbb" }
  def spec
    clean(JSON.parse(Timeout.timeout(TIMEOUT) { ask }[/\{.*\}/m].to_s))
  rescue ProjectShell::Error, Timeout::Error, JSON::ParserError => error
    Rails.logger.warn "DemoCatalog::Niche: static demo (#{error.class}: #{error.message.truncate(300)})"
    nil
  end

  def command
    [ "claude", "-p", prompt, "--model", MODEL, "--output-format", "text", "--setting-sources", "", "--tools", "", "--no-session-persistence" ]
  end

  def prompt
    <<~PROMPT
      A print-on-demand shop is described below. Write sample products for its preview, in English,
      as this shop would really sell them: short product names, the words printed on each (2 to 5
      words, witty or warm in the shop's voice, never a brand or a real person's name), and one plain
      sentence describing each (material, fit or size, printed to order).

      Products, one each: tee (a classic tee), sale_tee (a second tee), hoodie, sweatshirt, mug,
      poster, tote, stickers (a pack of three, with three short phrases). Also three collection names
      for this shop (one for apparel, one for gifts, one for a theme of its own), and an accent color
      that suits it, as a hex.

      Reply with JSON only:
      {"products": {"tee": {"title": "", "phrase": "", "description": ""}, "sale_tee": {...}, "hoodie": {...},
      "sweatshirt": {...}, "mug": {...}, "poster": {...}, "tote": {...}, "stickers": {"title": "", "phrases": ["", "", ""], "description": ""}},
      "collections": ["", "", ""], "accent": "#rrggbb"}

      The shop: #{@request.truncate(2000)}
    PROMPT
  end

  private
    def ask
      ProjectShell.new(Dir.tmpdir).run(*command, env: AgentRunner.claude_env)
    end

    def clean(raw)
      products = raw["products"].to_h.slice(*ROLES).transform_values do |product|
        { "title" => text(product["title"], 60), "phrase" => text(product["phrase"], 40), "description" => text(product["description"], 240),
          "phrases" => Array(product["phrases"]).map { |phrase| text(phrase, 24) }.compact_blank.first(3) }.compact_blank
      end
      collections = Array(raw["collections"]).map { |name| text(name, 30) }.compact_blank.uniq.first(3)
      accent = raw["accent"].to_s[/\A#\h{6}\z/] || "#d9643a"
      complete = ROLES.all? { |role| products.dig(role, "title") && (role == "stickers" ? products.dig(role, "phrases")&.size == 3 : products.dig(role, "phrase")) }
      { "products" => products, "collections" => collections, "accent" => accent } if complete && collections.size == 3
    end

    def text(value, limit) = value.to_s.squish.truncate(limit, separator: " ", omission: "").presence
end
