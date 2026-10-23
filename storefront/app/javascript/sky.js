// The night sky over a city at a moment, for a star map: the stars and the constellations' lines
// (public/personalization/sky.json, from d3-celestial) as seen looking up, north at the top and east
// on the left, the horizon the edge (a stereographic projection from the zenith). The Platform's
// Personalization::Sky draws the print file with the same arithmetic.

let data, cities

export async function load() {
  [ data, cities ] = await Promise.all([
    data || fetch("/personalization/sky.json").then((response) => response.json()),
    cities || fetch("/personalization/cities.json").then((response) => response.json())
  ])
}

// The SVG of the sky for "2014-06-21T22:00" (the city's own time) over a city id, or null.
export function draw(value, place, { sky, ink, lines }) {
  const city = cities?.find((candidate) => candidate.id === place)
  const parts = /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}))?$/.exec(value || "")
  if (!data || !city || !parts) return null

  const [ , year, month, day, hour = "22", minute = "00" ] = parts.map(Number)
  const project = projector(utc(year, month, day, hour, minute, city.tz), city.lat, city.lon)
  const ns = "http://www.w3.org/2000/svg"
  const svg = document.createElementNS(ns, "svg")
  svg.setAttribute("viewBox", "-1 -1 2 2")
  svg.setAttribute("preserveAspectRatio", "xMidYMid meet")
  Object.assign(svg.style, { position: "absolute", inset: 0, width: "100%", height: "100%" })
  const disc = document.createElementNS(ns, "circle")
  disc.setAttribute("r", 1)
  disc.setAttribute("fill", sky)
  svg.append(disc)
  if (lines) {
    let d = ""
    for (const line of data.lines) {
      for (let index = 1; index < line.length; index++) {
        const from = project(...line[index - 1]), to = project(...line[index])
        if (from && to) d += `M${from[0].toFixed(4)} ${from[1].toFixed(4)}L${to[0].toFixed(4)} ${to[1].toFixed(4)}`
      }
    }
    const path = document.createElementNS(ns, "path")
    Object.entries({ d, fill: "none", stroke: ink, "stroke-width": 0.003, "stroke-opacity": 0.35, "stroke-linecap": "round" }).forEach(([ name, value ]) => path.setAttribute(name, value))
    svg.append(path)
  }
  for (const [ ra, dec, magnitude ] of data.stars) {
    const point = project(ra, dec)
    if (!point) continue
    const star = document.createElementNS(ns, "circle")
    star.setAttribute("cx", point[0].toFixed(4))
    star.setAttribute("cy", point[1].toFixed(4))
    star.setAttribute("r", Math.min(Math.max(0.004 * (5.6 - magnitude), 0.003), 0.02))
    star.setAttribute("fill", ink)
    svg.append(star)
  }
  return svg
}

// A star's place on the map (right ascension and declination in degrees), or null below the horizon.
function projector(time, latitude, longitude) {
  const julian = time / 86400000 + 2440587.5
  const sidereal = (280.46061837 + 360.98564736629 * (julian - 2451545.0) + longitude) % 360
  const radians = (degrees) => degrees * Math.PI / 180
  const phi = radians(latitude)
  return (ra, dec) => {
    const hourAngle = radians(sidereal - ra), delta = radians(dec)
    const altitude = Math.asin(Math.max(-1, Math.min(1, Math.sin(phi) * Math.sin(delta) + Math.cos(phi) * Math.cos(delta) * Math.cos(hourAngle))))
    if (altitude < 0) return null

    const azimuth = Math.atan2(-Math.cos(delta) * Math.sin(hourAngle), Math.sin(delta) * Math.cos(phi) - Math.cos(delta) * Math.cos(hourAngle) * Math.sin(phi))
    const distance = Math.cos(altitude) / (1 + Math.sin(altitude))
    return [ -distance * Math.sin(azimuth), -distance * Math.cos(azimuth) ]
  }
}

// The moment, in milliseconds, of a time on a city's clock (its time zone, summer time included).
function utc(year, month, day, hour, minute, zone) {
  const wall = Date.UTC(year, month - 1, day, hour, minute)
  const offset = (moment) => {
    const parts = Object.fromEntries(new Intl.DateTimeFormat("en-US", { timeZone: zone, hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit" })
      .formatToParts(moment).filter((part) => part.type !== "literal").map((part) => [ part.type, +part.value ]))
    return Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute) - moment
  }
  const guess = wall - offset(wall)
  return wall - offset(guess)
}
