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
          <radialGradient id="room" cx="50%" cy="38%" r="80%"><stop offset="0" stop-color="#f7f4ee"/><stop offset="0.7" stop-color="#ebe5db"/><stop offset="1" stop-color="#ddd5c8"/></radialGradient>
          <radialGradient id="contact"><stop offset="0" stop-color="#2b2219" stop-opacity="0.30"/><stop offset="1" stop-color="#2b2219" stop-opacity="0"/></radialGradient>
          <filter id="lift" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="14" stdDeviation="16" flood-color="#3b3226" flood-opacity="0.18"/></filter>
          <filter id="soft" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="18"/></filter>
          <filter id="grain" x="0" y="0" width="100%" height="100%">
            <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed="4" result="noise"/>
            <feColorMatrix in="noise" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.16 0"/>
            <feComposite in2="SourceGraphic" operator="in"/>
          </filter>
          <filter id="weave" x="0" y="0" width="100%" height="100%">
            <feTurbulence type="turbulence" baseFrequency="0.02 0.9" numOctaves="1" seed="7" result="warp"/>
            <feColorMatrix in="warp" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.22 0" result="lines"/>
            <feComposite in="lines" in2="SourceGraphic" operator="in"/>
          </filter>
          <filter id="ink" x="-5%" y="-5%" width="110%" height="110%">
            <feTurbulence type="fractalNoise" baseFrequency="0.6" numOctaves="2" seed="11" result="noise"/>
            <feDisplacementMap in="SourceGraphic" in2="noise" scale="4" xChannelSelector="R" yChannelSelector="G" result="bent"/>
            <feColorMatrix in="noise" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -0.7 1.3" result="wear"/>
            <feComposite in="bent" in2="wear" operator="in"/>
          </filter>
          <linearGradient id="sheen" x1="0" x2="1"><stop offset="0" stop-color="#000" stop-opacity="0.16"/><stop offset="0.22" stop-color="#fff" stop-opacity="0.06"/><stop offset="0.5" stop-color="#fff" stop-opacity="0"/><stop offset="0.8" stop-color="#000" stop-opacity="0.06"/><stop offset="1" stop-color="#000" stop-opacity="0.2"/></linearGradient>
          <linearGradient id="drop" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="0.07"/><stop offset="1" stop-color="#000" stop-opacity="0.12"/></linearGradient>
          <linearGradient id="cylinder" x1="0" x2="1">
            <stop offset="0" stop-color="#000" stop-opacity="0.22"/><stop offset="0.12" stop-color="#000" stop-opacity="0.06"/>
            <stop offset="0.3" stop-color="#fff" stop-opacity="0.55"/><stop offset="0.38" stop-color="#fff" stop-opacity="0.1"/>
            <stop offset="0.75" stop-color="#000" stop-opacity="0.04"/><stop offset="1" stop-color="#000" stop-opacity="0.28"/>
          </linearGradient>
          <linearGradient id="glass" x1="0" y1="0" x2="1" y2="1"><stop offset="0.25" stop-color="#fff" stop-opacity="0"/><stop offset="0.38" stop-color="#fff" stop-opacity="0.16"/><stop offset="0.5" stop-color="#fff" stop-opacity="0"/></linearGradient>
        </defs>
        <rect width="100%" height="100%" fill="url(#room)"/>
        <rect width="100%" height="100%" fill="#8a7a66" filter="url(#grain)" opacity="0.5"/>
        #{public_send(:"draw_#{@kind}")}
      </svg>
    SVG
  end

  def draw_tee = garment(<<~PATH, 700, collar: "M470 278 Q600 352 730 278", sleeves: [ [ 190, 520, 310, 592 ], [ 890, 592, 1010, 520 ] ])
    M330 330 L470 278 Q600 352 730 278 L870 330 L1010 520 L890 592 L860 545 L860 1180 L340 1180 L340 545 L310 592 L190 520 Z
  PATH

  def draw_sweatshirt = garment(<<~PATH, 690, collar: "M470 280 Q600 345 730 280", sleeves: [ [ 200, 900, 295, 925 ], [ 905, 925, 1000, 900 ] ], ribbed: true)
    M330 330 L470 280 Q600 345 730 280 L870 330 L1000 900 L905 925 L860 600 L860 1180 L340 1180 L340 600 L295 925 L200 900 Z
  PATH

  def draw_hoodie
    hood = <<~SVG
      <path d="M455 300 Q600 130 745 300 Q600 385 455 300 Z" fill="#{shade(fabric, -0.14)}" filter="url(#lift)"/>
      <path d="M490 300 Q600 205 710 300 Q600 350 490 300 Z" fill="#{shade(fabric, -0.38)}"/>
    SVG
    strings = %(<path d="M560 350 L552 520 M640 350 L648 520" stroke="#{shade(fabric, light? ? -0.25 : 0.55)}" stroke-width="7" stroke-linecap="round"/>)
    pocket = %(<path d="M430 930 L470 860 L730 860 L770 930 L770 1050 L430 1050 Z" fill="none" stroke="#{shade(fabric, -0.22)}" stroke-width="5" stroke-dasharray="2 9"/>)
    hood + garment(<<~PATH, 700, collar: nil, sleeves: [ [ 200, 910, 295, 935 ], [ 905, 935, 1000, 910 ] ], ribbed: true, extra: strings + pocket)
      M330 340 L470 290 Q600 360 730 290 L870 340 L1000 910 L905 935 L860 610 L860 1180 L340 1180 L340 610 L295 935 L200 910 Z
    PATH
  end

  def draw_mug
    body = "M330 480 L870 480 L870 1030 Q870 1070 830 1070 L370 1070 Q330 1070 330 1030 Z"
    <<~SVG
      <ellipse cx="610" cy="1080" rx="340" ry="40" fill="url(#contact)"/>
      <path d="M862 600 C1020 600 1020 930 862 930" fill="none" stroke="#e9e4dc" stroke-width="58" stroke-linecap="round"/>
      <path d="M862 600 C1020 600 1020 930 862 930" fill="none" stroke="#000" stroke-opacity="0.08" stroke-width="58" stroke-linecap="round" transform="translate(6 6)"/>
      <path d="M870 625 C985 630 985 900 870 905" fill="none" stroke="#fff" stroke-opacity="0.6" stroke-width="8"/>
      <path d="#{body}" fill="#f7f5f1"/>
      #{text_block(@phrase, x: 600, y: 790, width: 360, ink: @accent, serif: true, filter: true)}
      <path d="#{body}" fill="url(#cylinder)"/>
      <ellipse cx="600" cy="480" rx="270" ry="36" fill="#f3f0ea"/>
      <ellipse cx="600" cy="484" rx="252" ry="27" fill="#2d241e"/>
      <ellipse cx="600" cy="492" rx="232" ry="18" fill="#47382d"/>
    SVG
  end

  def draw_poster
    <<~SVG
      <ellipse cx="600" cy="1170" rx="320" ry="26" fill="url(#contact)"/>
      <g filter="url(#lift)"><rect x="330" y="250" width="540" height="900" fill="#1e1c1a"/></g>
      <path d="M330 250 L870 250 L846 274 L354 274 Z" fill="#3a3632"/><path d="M330 1150 L870 1150 L846 1126 L354 1126 Z" fill="#0f0e0d"/>
      <rect x="354" y="274" width="492" height="852" fill="#f6f3ec"/>
      <rect x="354" y="274" width="492" height="852" fill="#8a7a66" filter="url(#grain)" opacity="0.6"/>
      <rect x="354" y="274" width="492" height="852" fill="none" stroke="#000" stroke-opacity="0.12" stroke-width="6"/>
      <g filter="url(#ink)">
        <circle cx="680" cy="470" r="70" fill="#{@accent}"/>
        <path d="M400 760 L520 560 L620 690 L700 600 L800 760 Z" fill="#2f4a3f"/>
        <path d="M520 560 L560 620 L540 615 L520 640 L495 600 Z" fill="#f6f3ec" opacity="0.7"/>
      </g>
      #{text_block(@phrase, x: 600, y: 900, width: 400, ink: "#2f2a25", size: 60, filter: true)}
      <rect x="354" y="274" width="492" height="852" fill="url(#glass)"/>
    SVG
  end

  def draw_tote
    bag = "M380 540 L820 540 L826 1100 L374 1100 Z"
    <<~SVG
      <ellipse cx="600" cy="1110" rx="300" ry="28" fill="url(#contact)"/>
      <path d="M470 560 C465 360 735 360 730 560" fill="none" stroke="#cfc2a7" stroke-width="34"/>
      <path d="M470 560 C465 360 735 360 730 560" fill="none" stroke="#000" stroke-opacity="0.12" stroke-width="34" stroke-dasharray="2 10"/>
      <g filter="url(#lift)"><path d="#{bag}" fill="#{GARMENTS["natural"]}"/></g>
      <path d="#{bag}" fill="#5b4a33" filter="url(#weave)"/>
      <path d="#{bag}" fill="#5b4a33" filter="url(#grain)" opacity="0.7"/>
      <path d="M380 590 L820 590" stroke="#000" stroke-opacity="0.12" stroke-width="3" stroke-dasharray="6 6"/>
      <path d="M470 545 L470 600 M730 545 L730 600" stroke="#000" stroke-opacity="0.15" stroke-width="10"/>
      #{folds(bag, [ "M520 600 Q540 850 505 1095", "M700 640 Q680 860 720 1095" ])}
      #{text_block(@phrase, x: 600, y: 830, width: 340, ink: "#2f3a2c", serif: true, filter: true)}
      <path d="#{bag}" fill="url(#sheen)"/>
    SVG
  end

  def draw_stickers
    a, b, c = (@phrases + [ "", "", "" ]).first(3)
    <<~SVG
      <g filter="url(#lift)">
        <circle cx="430" cy="470" r="185" fill="#fff"/>
        <g transform="rotate(8 790 520)"><rect x="620" y="370" width="340" height="300" rx="46" fill="#fff"/></g>
        <path d="M600 780 L655 905 L790 915 L690 1000 L725 1135 L600 1060 L475 1135 L510 1000 L410 915 L545 905 Z" fill="#fff" stroke="#fff" stroke-width="10" stroke-linejoin="round"/>
      </g>
      <circle cx="430" cy="470" r="160" fill="#f1e3c6"/>
      <g transform="rotate(8 790 520)"><rect x="644" y="394" width="292" height="252" rx="32" fill="#{@accent}"/></g>
      <path d="M600 815 L645 920 L755 928 L672 998 L700 1105 L600 1045 L500 1105 L528 998 L445 928 L555 920 Z" fill="#f2c25a"/>
      #{text_block(a, x: 430, y: 480, width: 250, ink: "#2f4a3f", limit: 9)}
      #{text_block(b, x: 790, y: 528, width: 230, ink: "#fff", rotate: 8, limit: 8)}
      #{text_block(c, x: 600, y: 985, width: 130, ink: "#3a2a12", limit: 8)}
      <path d="M300 360 Q380 300 470 310" fill="none" stroke="#fff" stroke-opacity="0.55" stroke-width="16" stroke-linecap="round"/>
      <g transform="rotate(8 790 520)"><path d="M660 400 L900 400" stroke="#fff" stroke-opacity="0.35" stroke-width="12" stroke-linecap="round"/></g>
    SVG
  end

  private
    def fabric = GARMENTS.fetch(@color, GARMENTS["white"])
    def light? = luminance(fabric) > 0.55

    # The garment laid flat: the cloth with its weave, soft folds, side shading, a ribbed collar
    # and hems with their stitches, and the words printed into it.
    def garment(path, text_y, collar:, sleeves:, ribbed: false, extra: "")
      path = path.strip
      ink = light? ? "#26221e" : "#f2ebe0"
      seam = shade(fabric, light? ? -0.2 : 0.18)
      cuffs = sleeves.map { |x1, y1, x2, y2| %(<path d="M#{x1} #{y1} L#{x2} #{y2}" stroke="#{seam}" stroke-width="#{ribbed ? 22 : 4}" stroke-opacity="#{ribbed ? 0.5 : 1}" stroke-dasharray="#{ribbed ? "3 5" : "8 7"}"/>) }
      <<~SVG
        <ellipse cx="600" cy="1190" rx="360" ry="34" fill="url(#contact)"/>
        <g filter="url(#lift)"><path d="#{path}" fill="#{fabric}"/></g>
        <path d="#{path}" fill="#{light? ? "#6b5d4c" : "#000"}" filter="url(#weave)" opacity="#{light? ? 0.5 : 0.9}"/>
        <path d="#{path}" fill="#{light? ? "#6b5d4c" : "#fff"}" filter="url(#grain)" opacity="#{light? ? 0.6 : 0.35}"/>
        #{folds(path, [ "M420 620 Q470 900 430 1170", "M780 600 Q730 880 770 1170", "M560 1000 Q610 1080 660 1170", "M360 420 Q450 470 470 560" ])}
        #{cuffs.join}
        <path d="M#{ribbed ? 340 : 342} #{ribbed ? 1150 : 1166} L#{ribbed ? 860 : 858} #{ribbed ? 1150 : 1166}" stroke="#{seam}" stroke-width="#{ribbed ? 58 : 4}" stroke-opacity="#{ribbed ? 0.35 : 1}" stroke-dasharray="#{ribbed ? "3 5" : "8 7"}"/>
        #{collar ? %(<path d="#{collar}" fill="none" stroke="#{shade(fabric, -0.22)}" stroke-width="24" stroke-linecap="round"/><path d="#{collar}" fill="none" stroke="#{seam}" stroke-width="3" stroke-dasharray="7 6" transform="translate(0 20)"/>) : ""}
        #{extra}
        #{text_block(@phrase, x: 600, y: text_y, width: 400, ink:, accent: @accent, filter: true)}
        <path d="#{path}" fill="url(#sheen)"/>
        <path d="#{path}" fill="url(#drop)"/>
      SVG
    end

    # Soft creases: a shadow and a highlight beside it, blurred and kept inside the shape.
    def folds(shape, lines)
      id = "clip#{shape.hash.abs}"
      creases = lines.map do |line|
        %(<path d="#{line}" fill="none" stroke="#000" stroke-opacity="#{light? ? 0.16 : 0.45}" stroke-width="26" filter="url(#soft)"/>) +
          %(<path d="#{line}" fill="none" stroke="#fff" stroke-opacity="#{light? ? 0.35 : 0.08}" stroke-width="14" filter="url(#soft)" transform="translate(22 0)"/>)
      end
      %(<clipPath id="#{id}"><path d="#{shape}"/></clipPath><g clip-path="url(##{id})">#{creases.join}</g>)
    end

    # The words in up to three lines, sized to their longest one; the last line in the accent.
    def text_block(words, x:, y:, width:, ink:, accent: nil, size: nil, serif: false, rotate: nil, limit: nil, filter: false)
      lines = wrap(words.to_s.upcase.squish, limit || (serif ? 14 : 12))
      return "" if lines.empty?

      size = [ (width / ([ lines.map(&:length).max, 4 ].max * 0.62)).floor, size || 120 ].min
      top = y - (lines.size - 1) * size * 0.55
      tspans = lines.each_with_index.map do |line, index|
        fill = accent && index == lines.size - 1 && lines.size > 1 ? accent : ink
        %(<tspan x="#{x}" y="#{(top + index * size * 1.1).round}" fill="#{fill}">#{CGI.escapeHTML(line)}</tspan>)
      end
      transform = rotate ? %( transform="rotate(#{rotate} #{x} #{y})") : ""
      transform += %( filter="url(#ink)" opacity="0.94") if filter
      %(<text text-anchor="middle" font-family="#{serif ? SERIF : SANS}" font-weight="#{serif ? 700 : 800}" font-size="#{size}" letter-spacing="2"#{transform}>#{tspans.join}</text>)
    end

    # Three lines at most: a long phrase gets longer lines (and a smaller size) instead of losing words.
    def wrap(text, limit)
      lines = text.split.each_with_object([]) do |word, wrapped|
        wrapped.last && (wrapped.last.length + word.length + 1) <= limit ? wrapped.last << " #{word}" : wrapped << word.dup
      end
      lines.size > 3 && limit < 40 ? wrap(text, limit + 2) : lines.first(3)
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
