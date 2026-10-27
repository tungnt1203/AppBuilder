# The look of a storefront the owner changes in the studio's Design tab without the agent: its
# colors, fonts, corners and width, read from and written to the theme's
# app/assets/tailwind/theme.css (put there by the template's bin/theme). Saving rebuilds the CSS
# and keeps the change as a version, like a turn.
class ProjectDesign
  include ActiveModel::Model
  include ActiveModel::Attributes

  FILE = "app/assets/tailwind/theme.css"
  FONTS_FILE = "app/assets/tailwind/fonts.css"
  HEX = /\A#\h{6}\z/
  CORNERS = { "square" => [ "0px", "0px" ], "slight" => [ "6px", "6px" ], "soft" => [ "10px", "14px" ], "round" => [ "16px", "22px" ] }
  WIDTHS = { "narrow" => "1100px", "standard" => "1200px", "wide" => "1400px" }
  # How far each step of the brand scale is mixed from the brand color, as layouts/_theme_colors
  # does for the owner's brand color; on a dark canvas the light and dark ends swap.
  SCALE = { 50 => 8, 100 => 15, 200 => 30, 300 => 50, 400 => 72, 500 => 88, 700 => 85, 800 => 70, 900 => 55, 950 => 40 }

  attribute :brand, :string
  attribute :background, :string
  attribute :text, :string
  attribute :accent, :string
  attribute :heading_font, :string
  attribute :text_font, :string
  attribute :corners, :string
  attribute :width, :string

  validates :brand, :background, :text, :accent, format: { with: HEX, message: "must be a color like #1a2b3c" }
  validates :heading_font, :text_font, inclusion: { in: ->(design) { design.fonts } }
  validates :corners, inclusion: { in: CORNERS.keys }
  validates :width, inclusion: { in: WIDTHS.keys }

  def self.for(project)
    new(project:).tap(&:read)
  end

  attr_reader :project

  def initialize(project:, **attributes)
    @project = project
    super(**attributes)
  end

  # A storefront made before themes has no theme.css with these names.
  def available?
    file.file? && %w[ --color-brand-600 --color-canvas --color-ink --font-display --font-sans ].all? { |name| source.include?("#{name}:") }
  end

  # The families the storefront ships (fonts.css), the monospace one aside.
  def fonts
    @fonts ||= begin
      css = project.path.join(FONTS_FILE)
      css.file? ? css.read.scan(/font-family:\s*"([^"]+)"/).flatten.uniq.sort - [ "JetBrains Mono" ] : []
    end
  end

  def read
    self.brand = color("--color-brand-600")
    self.background = color("--color-canvas")
    self.text = color("--color-ink")
    self.accent = color("--color-accent")
    self.heading_font = family("--font-display")
    self.text_font = family("--font-sans")
    self.corners = closest(CORNERS.transform_values { |(large, _)| large.to_i }, value("--radius-lg").to_i)
    self.width = closest(WIDTHS.transform_values(&:to_i), value("--page-width").to_i.nonzero? || 1200)
    self
  end

  # What changed from the saved file, in words, for the version's name: "brand #e8643c, Fraunces".
  def changes_from(saved)
    labels = { brand: "brand", background: "background", text: "text", accent: "accent" }
    words = labels.filter_map { |key, label| "#{label} #{public_send(key)}" if public_send(key) != saved.public_send(key) }
    words << heading_font if heading_font != saved.heading_font
    words << "#{text_font} for text" if text_font != saved.text_font
    words << "#{corners} corners" if corners != saved.corners
    words << "#{width} width" if width != saved.width
    words
  end

  # The theme's variables for these choices: what the file gets, and what the preview tries on
  # live before it's saved.
  def variables
    surface_follows = color("--color-surface").nil? || color("--color-surface") == color("--color-canvas")
    large, extra_large = CORNERS.fetch(corners)
    {
      "--color-canvas" => background, "--color-surface" => (background if surface_follows),
      "--color-ink" => text, "--color-accent" => accent,
      **brand_scale, "--color-on-brand" => on_brand,
      "--font-display" => replace_family(value("--font-display"), heading_font),
      "--font-sans" => replace_family(value("--font-sans"), text_font),
      "--radius-lg" => large, "--radius-xl" => extra_large, "--page-width" => WIDTHS.fetch(width)
    }.compact
  end

  # What the studio needs to try choices on in the preview the way #variables writes them.
  def preview_settings
    { display: value("--font-display"), sans: value("--font-sans"),
      surfaceFollows: color("--color-surface").nil? || color("--color-surface") == color("--color-canvas"),
      corners: CORNERS, widths: WIDTHS, scale: SCALE }
  end

  # Writes the file, rebuilds the CSS and keeps it as a version. False when invalid or unchanged.
  def save
    return false unless valid?

    saved = self.class.for(project)
    words = changes_from(saved)
    return false if words.empty?

    file.write(variables.reduce(source) { |css, (name, value)| set(css, name, value) })
    project.history.commit("Design: #{words.to_sentence}")
    project.sandbox.run("bin/rails", "tailwindcss:build")
    true
  end

  private
    def file
      project.path.join(FILE)
    end

    def source
      @source = nil if @source_mtime != (file.mtime if file.file?)
      @source_mtime = file.mtime if file.file?
      @source ||= file.file? ? file.read : ""
    end

    def value(name)
      source[/^\s*#{Regexp.escape(name)}:\s*([^;]+);/, 1]&.strip || source[/#{Regexp.escape(name)}:\s*([^;]+);/, 1]&.strip
    end

    def color(name)
      value(name)&.downcase.then { |found| found if found&.match?(HEX) }
    end

    def family(name)
      value(name).to_s[/"([^"]+)"/, 1]
    end

    def replace_family(stack, family)
      stack.to_s.sub(/"[^"]+"/, %("#{family}")).presence || %("#{family}", ui-sans-serif, system-ui, sans-serif)
    end

    def set(css, name, value)
      pattern = /(#{Regexp.escape(name)}:\s*)[^;]+;/
      css.match?(pattern) ? css.sub(pattern) { "#{$1}#{value};" } : css
    end

    def brand_scale
      dark_canvas = !light?(background)
      SCALE.to_h do |step, share|
        toward = (step < 600) ^ dark_canvas ? "white" : "black"
        [ "--color-brand-#{step}", "color-mix(in oklch, #{brand} #{share}%, #{toward})" ]
      end.merge("--color-brand-600" => brand)
    end

    # Dark or white words on the brand color, whichever reads better.
    def on_brand
      contrast(brand, "#1a1a1a") > contrast(brand, "#ffffff") ? "#1a1a1a" : "#ffffff"
    end

    def light?(hex)
      luminance(hex) > 0.4
    end

    def luminance(hex)
      channels = hex.to_s.delete("#").scan(/../).map { |pair| pair.to_i(16) / 255.0 }
      return 1.0 if channels.size != 3
      red, green, blue = channels.map { |channel| channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4 }
      0.2126 * red + 0.7152 * green + 0.0722 * blue
    end

    def contrast(first, second)
      high, low = [ luminance(first), luminance(second) ].sort.reverse
      (high + 0.05) / (low + 0.05)
    end

    def closest(options, number)
      options.min_by { |_, size| (size - number).abs }.first
    end
end
