# The night sky over a place at a moment, for a star map (BuyerInputs, kind "starmap"): the stars to
# magnitude 5 and the constellations' lines (lib/personalization/sky.json, from d3-celestial; its
# license beside it) as seen looking up, north at the top and east on the left, the horizon the
# circle's edge (a stereographic projection from the zenith). The storefront's preview draws it with
# the same arithmetic (personalize controller), and the print file from #svg.
class Personalization::Sky
  DATA = Rails.root.join("lib/personalization/sky.json")
  CITIES = Rails.root.join("lib/personalization/cities.json")
  WHEN = /\A(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?\z/
  DEFAULT_TIME = "22:00"

  def self.data = (@data ||= JSON.parse(DATA.read))

  # { "hanoi-vietnam" => { "id", "name", "lat", "lon", "tz" } }
  def self.cities = (@cities ||= JSON.parse(CITIES.read).index_by { |city| city["id"] })

  # The sky for "2014-06-21" or "2014-06-21T23:30" (the place's own time) over one of the cities, or nil.
  def self.for(value, place)
    city = cities[place.to_s] or return
    parts = value.to_s.match(WHEN)&.captures or return
    year, month, day, hour, minute = parts
    local = ActiveSupport::TimeZone[city["tz"]].local(year.to_i, month.to_i, day.to_i, (hour || DEFAULT_TIME[0, 2]).to_i, (minute || DEFAULT_TIME[3, 2]).to_i)
    new(local.utc, city["lat"], city["lon"]) if local.year.between?(1900, 2100)
  rescue ArgumentError
    nil
  end

  def initialize(time, latitude, longitude)
    @time, @latitude, @longitude = time, latitude, longitude
  end

  # [[x, y, magnitude]] of the stars above the horizon, x and y from -1 to 1.
  def stars
    self.class.data["stars"].filter_map { |ra, dec, magnitude| (point = project(ra, dec)) && [ *point, magnitude ] }
  end

  # [[[x, y], [x, y]]] of the constellations' lines whose both ends are above the horizon.
  def lines
    self.class.data["lines"].flat_map do |line|
      line.each_cons(2).filter_map { |(ra1, dec1), (ra2, dec2)| (from = project(ra1, dec1)) && (to = project(ra2, dec2)) && [ from, to ] }
    end
  end

  # The map as SVG, size pixels across: a disc of the sky's color, the stars (bigger the brighter)
  # and the constellations' lines in the ink's.
  def svg(size, sky:, ink:, lines: true)
    paths = lines ? self.lines.map { |(x1, y1), (x2, y2)| "M#{x1.round(4)} #{y1.round(4)}L#{x2.round(4)} #{y2.round(4)}" }.join : ""
    dots = stars.map { |x, y, magnitude| %(<circle cx="#{x.round(4)}" cy="#{y.round(4)}" r="#{self.class.radius(magnitude).round(4)}"/>) }.join
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{size}" height="#{size}" viewBox="-1 -1 2 2">
        <circle r="1" fill="#{sky}"/>
        <path d="#{paths}" fill="none" stroke="#{ink}" stroke-width="0.003" stroke-opacity="0.55" stroke-linecap="round"/>
        <g fill="#{ink}">#{dots}</g>
      </svg>
    SVG
  end

  # A star's dot, as a share of the map's radius: Sirius about 0.014, the faintest 0.0035.
  def self.radius(magnitude) = [ 0.012 * (5.5 - magnitude) / 6, 0.0035 ].max

  private
    # Where a star (right ascension and declination, degrees) is on the map, or nil below the horizon.
    def project(ra, dec)
      hour_angle = radians(sidereal - ra)
      latitude, declination = radians(@latitude), radians(dec)
      altitude = Math.asin((Math.sin(latitude) * Math.sin(declination) + Math.cos(latitude) * Math.cos(declination) * Math.cos(hour_angle)).clamp(-1, 1))
      return if altitude.negative?

      azimuth = Math.atan2(-Math.cos(declination) * Math.sin(hour_angle),
        Math.sin(declination) * Math.cos(latitude) - Math.cos(declination) * Math.cos(hour_angle) * Math.sin(latitude))
      distance = Math.cos(altitude) / (1 + Math.sin(altitude))
      [ -distance * Math.sin(azimuth), -distance * Math.cos(azimuth) ]
    end

    # The local sidereal time, in degrees.
    def sidereal
      @sidereal ||= begin
        julian = @time.to_f / 86_400 + 2_440_587.5
        (280.46061837 + 360.98564736629 * (julian - 2_451_545.0) + @longitude) % 360
      end
    end

    def radians(degrees) = degrees * Math::PI / 180
end
