require "cgi"
require "open3"

# Draws a demo product's photo with the shop's own words printed on it (DemoCatalog::Niche): a
# tee, a hoodie, a sweatshirt, a mug, a poster, a tote or a sticker sheet, on a soft studio
# backdrop, at the size the static demo photos have (1200 × 1413), so the personalization boxes
# DemoCatalog places (the name on the tee, the photo on the mug, the names on the poster) still
# land on the print area. SVG drawn by rsvg-convert (libvips' own SVG loader stays blocked, as
# Active Storage has it, for uploaded files), then a JPEG by libvips.
class DemoCatalog::Mockup
  WIDTH, HEIGHT = 1200, 1413
  SANS = "Helvetica Neue, Arial, DejaVu Sans, sans-serif"
  SERIF = "Georgia, DejaVu Serif, serif"
  GARMENTS = {
    "black" => "#1f1f22", "white" => "#f4f2ee", "navy" => "#24304a", "sand" => "#cdb894", "forest" => "#33473a",
    "sage" => "#97a78c", "natural" => "#e7dfcf", "heather" => "#9a9ba0", "pink" => "#e9b9b9"
  }.freeze

  def self.jpeg(kind, **options) = new(kind, **options).jpeg

  def initialize(kind, phrase: "", phrases: [], color: "white", accent: "#d9643a")
    @kind, @phrase, @phrases, @color, @accent = kind.to_s, phrase.to_s, Array(phrases), color.to_s, accent.to_s
  end

  def jpeg
    png, status = Open3.capture2("rsvg-convert", "--format", "png", stdin_data: svg, binmode: true)
    raise "rsvg-convert couldn't draw the #{@kind}" unless status.success? && png.present?

    image = Vips::Image.new_from_buffer(png, "")
    (image.has_alpha? ? image.flatten(background: 255) : image).jpegsave_buffer(Q: 86, strip: true)
  end

  def svg
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{WIDTH}" height="#{HEIGHT}" viewBox="0 0 #{WIDTH} #{HEIGHT}">
        <defs>
          <radialGradient id="room" cx="50%" cy="42%" r="75%"><stop offset="0" stop-color="#faf8f4"/><stop offset="1" stop-color="#e6e0d6"/></radialGradient>
          <filter id="lift" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="18" stdDeviation="22" flood-color="#3b3226" flood-opacity="0.22"/></filter>
          <linearGradient id="sheen" x1="0" x2="1"><stop offset="0" stop-color="#fff" stop-opacity="0.10"/><stop offset="0.5" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.10"/></linearGradient>
        </defs>
        <rect width="100%" height="100%" fill="url(#room)"/>
        #{public_send(:"draw_#{@kind}")}
      </svg>
    SVG
  end

  def draw_tee = garment(<<~PATH, 700)
    M330 330 L470 278 Q600 352 730 278 L870 330 L1010 520 L890 592 L860 545 L860 1180 L340 1180 L340 545 L310 592 L190 520 Z
  PATH

  def draw_sweatshirt = garment(<<~PATH, 690)
    M330 330 L470 280 Q600 345 730 280 L870 330 L1000 900 L905 925 L860 600 L860 1180 L340 1180 L340 600 L295 925 L200 900 Z
  PATH

  def draw_hoodie
    hood = %(<path d="M455 300 Q600 140 745 300 Q600 380 455 300 Z" fill="#{shade(fabric, -0.12)}" filter="url(#lift)"/>)
    hood + garment(<<~PATH, 720)
      M330 340 L470 290 Q600 360 730 290 L870 340 L1000 910 L905 935 L860 610 L860 1180 L340 1180 L340 610 L295 935 L200 910 Z
    PATH
  end

  def draw_mug
    <<~SVG
      <g filter="url(#lift)">
        <path d="M860 600 C1010 600 1010 920 860 920" fill="none" stroke="#ebe7e1" stroke-width="56"/>
        <rect x="330" y="470" width="540" height="590" rx="40" fill="#f6f4f0"/>
        <ellipse cx="600" cy="472" rx="270" ry="34" fill="#3a2f28"/>
        <rect x="330" y="470" width="540" height="590" rx="40" fill="url(#sheen)"/>
      </g>
      #{text_block(@phrase, x: 600, y: 790, width: 360, ink: @accent, serif: true)}
    SVG
  end

  def draw_poster
    <<~SVG
      <g filter="url(#lift)"><rect x="330" y="250" width="540" height="900" fill="#1e1c1a"/><rect x="356" y="276" width="488" height="848" fill="#f3efe6"/></g>
      <circle cx="680" cy="470" r="70" fill="#{@accent}"/>
      <path d="M380 760 L520 560 L620 690 L700 600 L820 760 Z" fill="#2f4a3f"/>
      #{text_block(@phrase, x: 600, y: 900, width: 420, ink: "#2f2a25", size: 64)}
    SVG
  end

  def draw_tote
    <<~SVG
      <g filter="url(#lift)">
        <path d="M480 560 C480 380 720 380 720 560" fill="none" stroke="#d8ccb4" stroke-width="30"/>
        <rect x="380" y="540" width="440" height="560" fill="#{GARMENTS["natural"]}"/>
        <rect x="380" y="540" width="440" height="560" fill="url(#sheen)"/>
      </g>
      #{text_block(@phrase, x: 600, y: 830, width: 340, ink: "#2f3a2c", serif: true)}
    SVG
  end

  def draw_stickers
    a, b, c = (@phrases + [ "", "", "" ]).first(3)
    <<~SVG
      <g filter="url(#lift)">
        <circle cx="430" cy="470" r="185" fill="#fff"/><circle cx="430" cy="470" r="160" fill="#f1e3c6"/>
        <g transform="rotate(8 790 520)"><rect x="620" y="370" width="340" height="300" rx="46" fill="#fff"/><rect x="644" y="394" width="292" height="252" rx="32" fill="#{@accent}"/></g>
        <path d="M600 780 L655 905 L790 915 L690 1000 L725 1135 L600 1060 L475 1135 L510 1000 L410 915 L545 905 Z" fill="#fff"/>
        <path d="M600 815 L645 920 L755 928 L672 998 L700 1105 L600 1045 L500 1105 L528 998 L445 928 L555 920 Z" fill="#f2c25a"/>
      </g>
      #{text_block(a, x: 430, y: 480, width: 250, ink: "#2f4a3f", limit: 9)}
      #{text_block(b, x: 790, y: 528, width: 230, ink: "#fff", rotate: 8, limit: 8)}
      #{text_block(c, x: 600, y: 985, width: 130, ink: "#3a2a12", limit: 8)}
    SVG
  end

  private
    def fabric = GARMENTS.fetch(@color, GARMENTS["white"])
    def light? = luminance(fabric) > 0.55

    def garment(path, text_y)
      ink = light? ? "#26221e" : "#f5efe6"
      <<~SVG
        <g filter="url(#lift)"><path d="#{path.strip}" fill="#{fabric}"/><path d="#{path.strip}" fill="url(#sheen)"/></g>
        <path d="M470 278 Q600 352 730 278" fill="none" stroke="#{shade(fabric, -0.18)}" stroke-width="14"/>
        #{text_block(@phrase, x: 600, y: text_y, width: 400, ink:, accent: @accent)}
      SVG
    end

    # The words in up to three lines, sized to their longest one; the last line in the accent.
    def text_block(words, x:, y:, width:, ink:, accent: nil, size: nil, serif: false, rotate: nil, limit: nil)
      lines = wrap(words.to_s.upcase.squish, limit || (serif ? 14 : 12))
      return "" if lines.empty?

      size ||= [ (width / ([ lines.map(&:length).max, 4 ].max * 0.62)).floor, 120 ].min
      top = y - (lines.size - 1) * size * 0.55
      tspans = lines.each_with_index.map do |line, index|
        fill = accent && index == lines.size - 1 && lines.size > 1 ? accent : ink
        %(<tspan x="#{x}" y="#{(top + index * size * 1.1).round}" fill="#{fill}">#{CGI.escapeHTML(line)}</tspan>)
      end
      transform = rotate ? %( transform="rotate(#{rotate} #{x} #{y})") : ""
      %(<text text-anchor="middle" font-family="#{serif ? SERIF : SANS}" font-weight="#{serif ? 700 : 800}" font-size="#{size}" letter-spacing="2"#{transform}>#{tspans.join}</text>)
    end

    def wrap(text, limit)
      text.split.each_with_object([]) do |word, lines|
        lines.last && (lines.last.length + word.length + 1) <= limit ? lines.last << " #{word}" : lines << word.dup
      end.first(3)
    end

    def shade(hex, amount)
      rgb = hex.delete("#").scan(/../).map { |part| part.to_i(16) }
      format("#%02x%02x%02x", *rgb.map { |c| (c + (amount.negative? ? c : 255 - c) * amount).round.clamp(0, 255) })
    end

    def luminance(hex)
      r, g, b = hex.delete("#").scan(/../).map { |part| part.to_i(16) / 255.0 }
      0.2126 * r + 0.7152 * g + 0.0722 * b
    end
end
