require "pathname"
require "open3"
require "tmpdir"

# A Hallmark theme (.claude/skills/hallmark/references/themes/<slug>.md) made the storefront's
# material: what its pages are made of (paper, ink, faces, corners, depth, controls) over the
# layout bin/theme put in place, which keeps its structure. Written into
# app/assets/tailwind/theme.css:
#
# - the names every page reads (canvas, ink, brand…, fonts, corners) in @theme, as hex, so the
#   studio's Design tab can change them;
# - Hallmark's shared scale and the material's other tokens in :root, its own names tied to the
#   page's where they mean the same thing (paper is the canvas, rule the line);
# - its headings and its build hint (the CSS that makes it recognizable), and its photo treatment
#   as .photo, for the home page's lifestyle photos (never product photos).
#
# Its fonts load from Google Fonts or Fontshare in app/views/layouts/_fonts.html.erb.
class HallmarkMaterial
  SKILL = ".claude/skills/hallmark"
  THEME_CSS = "app/assets/tailwind/theme.css"
  FONTS = "app/views/layouts/_fonts.html.erb"
  # Hallmark tokens with the same name as the page's: the page's (in @theme) win, set from them.
  SHARED_NAMES = %w[ --color-ink --color-muted --color-accent --font-display ].freeze
  # Hallmark's type scale steps that Tailwind's text-* utilities use too: left to Tailwind.
  TAILWIND_TEXT = %w[ --text-xs --text-sm --text-md --text-lg --text-xl --text-2xl --text-3xl ].freeze
  # How far each step of the brand scale is mixed from the brand color, as layouts/_theme_colors
  # and the Design tab do it.
  SCALE = { 50 => 8, 100 => 15, 200 => 30, 300 => 50, 400 => 72, 500 => 88, 700 => 85, 800 => 70, 900 => 55, 950 => 40 }.freeze
  EMPTY_FONTS = "<%# The material's fonts (bin/theme material <slug>); the layout's own are in fonts.css. %>\n".freeze

  attr_reader :root, :slug

  def self.all(root)
    Pathname(root).join(SKILL, "references/themes").glob("*.md").map { |file| file.basename(".md").to_s } - [ "README" ]
  end

  def initialize(root, slug)
    @root, @slug = Pathname(root).expand_path, slug.to_s
    raise ArgumentError, "No Hallmark theme named #{slug}. See #{SKILL}/references/themes/." unless file.file?
  end

  def file = root.join(SKILL, "references/themes/#{slug}.md")
  def source = @source ||= file.read
  def header = @header ||= source[/\A---\n(.*?)\n---/m, 1].to_s.lines.to_h { |line| line.chomp.split(": ", 2) }
  def name = header.fetch("name", slug)
  def material = header["material"].to_s

  # The theme's own tokens, as written in its file: { "--color-paper" => "oklch(97% 0.006 55)", … }.
  def tokens
    @tokens ||= block(:css, after: "## Tokens").to_s[/:root\s*\{(.*)\}/m, 1].to_s.scan(/(--[\w-]+)\s*:\s*([^;]+);/).to_h { |key, value| [ key, value.strip ] }
  end

  # Hallmark's shared scale (spacing, type steps, easing, durations), from the theme's scaffold.
  def scaffold
    @scaffold ||= Dir.mktmpdir do |dir|
      _, status = Open3.capture2e("node", root.join(SKILL, "scripts/theme.mjs").to_s, "scaffold", slug, chdir: dir)
      raise "Hallmark's scaffold failed for #{slug}" unless status.success?
      { tokens: File.read(File.join(dir, "tokens.css")), base: File.read(File.join(dir, "base.css")) }
    end
  end

  def font_links = block(:html, after: "## Build hint").to_s.scan(/<link\b[^>]*>/)
  def build_hint = block(:css, after: "## Build hint").to_s.strip
  def photo_filter = scaffold[:base][/\[data-slot\] > img \{ (filter:[^}]*)\}/, 1]&.strip&.delete_suffix(";")

  def families
    font_links.flat_map do |link|
      href = link[/href="([^"]+)"/, 1].to_s.gsub("&amp;", "&")
      href.scan(/family=([^:&]+)/).flatten.map { |family| family.tr("+", " ") } +
        href.scan(/f\[\]=([^@&]+)/).flatten.map { |family| family.split("-").map(&:capitalize).join(" ") }
    end.uniq
  end

  def paper = hex(tokens.fetch("--color-paper"))
  def dark? = luminance(paper) < 0.4

  # A restrained material keeps its accent for one small thing: buttons are its ink.
  def brand
    restrained = header["posture"].to_s.start_with?("restrained")
    restrained ? [ hex(tokens.fetch("--color-ink")), paper ] : [ hex(tokens.fetch("--color-accent")), hex(tokens.fetch("--color-accent-ink", tokens.fetch("--color-ink"))) ]
  end

  def apply!
    css = root.join(THEME_CSS)
    width = css.read[/--page-width:\s*([^;]+);/, 1] || "1200px"
    css.write(theme_css(width))
    root.join(FONTS).write(fonts_partial)
  end

  # The layout bin/theme put in place (clean, bold…): its theme.css names it, and a material's
  # first line keeps the name.
  def layout
    css = root.join(THEME_CSS)
    (css.read[/\A\/\* Theme "(\w+)"/, 1] || css.read[/layout: (\w+)/, 1] if css.file?) || "clean"
  end

  def theme_css(page_width)
    brand_color, on_brand = brand
    <<~CSS
      /* Hallmark · shape: <the draw's shape> · layout: #{layout} · genre: #{header["genre"]} · theme: #{name} (deal) · job: buy · draw: <seed>
       * hero: <the draw's posture> · nav: <the draw's nav> · footer: <the draw's footer> · imagery: <photographs, the product, or none> · signature: <the one thing a buyer remembers, made from this shop's products>
       * axes: #{header.values_at("paper", "display", "accent").compact.join(" / ")} · posture: #{header["posture"]} · contrast: pass · fold: pass */
      /* Hallmark · pre-emit critique: P_ H_ E_ S_ R_ V_ · weakest: _, <what you did about it> */

      /* Material "#{name}" from Hallmark (bin/theme material #{slug}), over the layout bin/theme put in
         place: #{material}.
         Read #{SKILL}/references/themes/#{slug}.md for how it builds (surfaces, controls, motion,
         voice, do-nots). The colors, fonts and corners in @theme are its tokens as hex, so the studio's
         Design tab can change them; its other tokens and its build hint follow.

         Names every page reads:
         - brand-50…950   buttons, links, badges (600 is the button; on-brand is the text on it)
         - accent         the sale badge and small signals (on-accent is the text on it)
         - canvas, surface (fields, cards), surface-muted (photo backgrounds, hovers), ink, muted, line
         - radius-lg      buttons and fields; radius-xl cards, photos, dialogs
         - font-display   headings; font-sans text (families from layouts/_fonts)
         - --page-width   how wide the content runs on a wide screen (.page-width) */
      @theme {
        --font-sans: #{font(:body)};
        --font-display: #{font(:display)};
        --font-mono: #{tokens.fetch("--font-outlier", '"JetBrains Mono", ui-monospace, monospace')};

        --radius-lg: #{tokens.fetch("--radius-input", tokens.fetch("--radius-card", "8px"))};
        --radius-xl: #{tokens.fetch("--radius-card", "8px")};

        --color-canvas: #{paper};
        --color-surface: #{paper};
        --color-surface-muted: #{hex(tokens.fetch("--color-paper-2", tokens.fetch("--color-paper")))};
        --color-ink: #{hex(tokens.fetch("--color-ink"))};
        --color-muted: #{hex(tokens.fetch("--color-muted"))};
        --color-line: #{hex(tokens.fetch("--color-rule"))};
        --color-accent: #{hex(tokens.fetch("--color-accent"))};
        --color-on-accent: #{hex(tokens.fetch("--color-accent-ink", tokens.fetch("--color-ink")))};
        --color-on-brand: #{on_brand};

      #{scale(brand_color).map { |step, color| "  --color-brand-#{step}: #{color};" }.join("\n")}
      }

      :root {
        --page-width: #{page_width};
        color-scheme: #{dark? ? "dark" : "light"};
      #{root_tokens.map { |key, value| "  #{key}: #{value};" }.join("\n")}
      }

      @layer base {
        body { font-family: var(--font-sans); }
        h1, h2, h3 { font-family: var(--font-display); font-weight: var(--display-weight, 600); letter-spacing: var(--tracking-display, normal); font-synthesis: none; }
      }

      /* The material's build hint (#{slug}.md): what makes it recognizable. Buttons are .btn. */
      @layer components {
      #{build_hint.gsub(/^/, "  ")}
      }

      /* Lifestyle photos (the home page's hero and story, never product photos) take the material's treatment. */
      .photo { #{photo_filter || "filter: none"}; }
    CSS
  end

  def fonts_partial
    return EMPTY_FONTS if font_links.empty?

    "<%# The material's fonts (bin/theme material #{slug}): #{families.join(", ")}. %>\n" +
      %(<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n) +
      font_links.join("\n") + "\n"
  end

  private
    def block(kind, after:)
      section = source.split(after, 2)[1].to_s.split(/^## /, 2).first
      section[/```#{kind}\n(.*?)```/m, 1]
    end

    def font(role)
      value = role == :display ? tokens.fetch("--font-display") : tokens.fetch("--font-body", "var(--font-display)")
      value == "var(--font-display)" ? tokens.fetch("--font-display") : value
    end

    # Hallmark's names the page doesn't have, with the ones that mean the page's own tied to them.
    def root_tokens
      shared = scaffold[:tokens][/:root \{(.*?)--color-paper:/m, 1].to_s.scan(/(--[\w-]+)\s*:\s*([^;]+);/).to_h
      shared = shared.except(*TAILWIND_TEXT, "color-scheme")
      # Textures are files a Hallmark page writes beside itself; a storefront has none of them.
      own = tokens.except(*SHARED_NAMES).transform_values { |value| value.match?(/\Aurl\(/) ? "none" : value }
      own = own.merge("--color-paper" => "var(--color-canvas)", "--color-paper-2" => "var(--color-surface-muted)",
        "--color-rule" => "var(--color-line)", "--color-accent-ink" => "var(--color-on-accent)")
      own["--font-body"] = "var(--font-sans)" if own.key?("--font-body")
      shared.merge(own)
    end

    def scale(brand)
      toward_light, toward_dark = dark? ? %w[ #000000 #ffffff ] : %w[ #ffffff #000000 ]
      (SCALE.map { |step, share| [ step, mix(brand, share, step < 600 ? toward_light : toward_dark) ] } << [ 600, brand ]).sort_by(&:first)
    end

    def mix(color, share, other)
      a, b = rgb(color), rgb(other)
      format("#%02x%02x%02x", *a.zip(b).map { |x, y| (x * share / 100.0 + y * (100 - share) / 100.0).round })
    end

    def rgb(hex) = hex.delete("#").scan(/../).map { |part| part.to_i(16) }

    def luminance(hex)
      r, g, b = rgb(hex).map { |part| part / 255.0 }.map { |c| c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
      0.2126 * r + 0.7152 * g + 0.0722 * b
    end

    # A CSS color as #rrggbb: oklch(L% C H [/ a]), oklch(L C H), #rgb or #rrggbb.
    def hex(value)
      value = value.to_s.strip
      return "#" + value.delete("#").chars.map { |c| c * (value.size == 4 ? 2 : 1) }.join.downcase[0, 6] if value.match?(/\A#\h{3}(\h{3})?\z/)

      l, c, h = value.match(/oklch\(\s*([\d.]+)(%?)\s+([\d.]+)\s+([\d.]+)/)&.then { |m| [ m[2] == "%" ? m[1].to_f / 100 : m[1].to_f, m[3].to_f, m[4].to_f ] } ||
        raise(ArgumentError, "Can't read the color #{value.inspect} in #{file}")
      a, b = c * Math.cos(h * Math::PI / 180), c * Math.sin(h * Math::PI / 180)
      lms = [ l + 0.3963377774 * a + 0.2158037573 * b, l - 0.1055613458 * a - 0.0638541728 * b, l - 0.0894841775 * a - 1.2914855480 * b ].map { |x| x**3 }
      linear = [ [ 4.0767416621, -3.3077115913, 0.2309699292 ], [ -1.2684380046, 2.6097574011, -0.3413193965 ], [ -0.0041960863, -0.7034186147, 1.7076147010 ] ]
        .map { |row| row.zip(lms).sum { |k, x| k * x } }
      format("#%02x%02x%02x", *linear.map { |x| x <= 0.0031308 ? 12.92 * x : 1.055 * x**(1 / 2.4) - 0.055 }.map { |x| (x.clamp(0, 1) * 255).round })
    end
end
