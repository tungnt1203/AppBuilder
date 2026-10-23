import { Controller } from "@hotwired/stimulus"
import * as sky from "sky"

// What the buyer adds to a product, on its photo where the shop placed it. Each layer is a box in
// fractions of the photo (data-box), laid over the photo as it shows (cropped to fill its frame).
// Text is shrunk to fit its box; a photo fills it, framed by a zoom and the point kept in view
// ("zoom,x,y", as the print will be); a picture the buyer picks fits it; a color fills it.
//
// On the product page a layer follows its field (data-key): the text the buyer types and the font
// and color they pick, or the photo they choose, shown at once and sent to the Platform meanwhile
// (its token goes in the field), which they move by dragging it and zoom with the slider. It shows
// only on the photos the shop chose (data-photos, none: all). A smaller copy of the photo (a
// "mirror", by the fields on phones, where the photo has scrolled away) shows the same.
// On a cart or order line a layer carries its text, font and color, or its photo and framing.
export default class extends Controller {
  static targets = [ "photo", "mirror", "layer" ]

  connect() {
    this.photos = {}
    this.resize = new ResizeObserver(() => this.render())
    this.swap = new MutationObserver(() => this.render())
    if (this.hasPhotoTarget) this.swap.observe(this.photoTarget, { attributes: true, attributeFilter: [ "src" ] })
    for (const photo of this.frames()) {
      this.resize.observe(photo)
      photo.addEventListener("load", this.render)
    }
    this.layerTargets.filter((layer) => layer.dataset.kind === "photo" && layer.dataset.key).forEach((layer) => {
      layer.addEventListener("pointerdown", this.grab)
      layer.addEventListener("pointermove", this.move)
      layer.addEventListener("pointerup", this.drop)
      layer.addEventListener("pointercancel", this.drop)
    })
    this.element.addEventListener("submit", this.check, true)
    document.fonts.ready.then(this.render)
    if (this.layerTargets.some((layer) => layer.dataset.kind === "starmap")) sky.load().then(this.render)
    this.render()
  }

  disconnect() {
    this.element.removeEventListener("submit", this.check, true)
    this.resize.disconnect()
    this.swap.disconnect()
    for (const photo of this.frames()) photo.removeEventListener("load", this.render)
    Object.values(this.photos).forEach(({ url }) => URL.revokeObjectURL(url))
  }

  // An input or a pick changed (the form is inside this controller on the product page). A star
  // map's day and time make its value, "2014-06-21T22:00".
  update() {
    this.element.querySelectorAll("[data-personalize-starmap-value]").forEach((value) => {
      const key = value.dataset.personalizeStarmapValue
      const date = this.element.querySelector(`[data-personalize-starmap-date="${key}"]`)?.value
      const time = this.element.querySelector(`[data-personalize-starmap-time="${key}"]`)?.value
      value.value = date ? (time ? `${date}T${time}` : date) : ""
    })
    this.render()
  }

  // The buyer chose a photo: shown at once, framed whole, and sent to the Platform for its token.
  async pick(event) {
    const key = event.target.dataset.personalizePick
    const file = event.target.files[0]
    if (!file) return

    if (this.photos[key]) URL.revokeObjectURL(this.photos[key].url)
    this.photos[key] = { url: URL.createObjectURL(file), zoom: 1, x: 0.5, y: 0.5 }
    this.field(key, "framing").forEach((element) => { element.hidden = false })
    this.field(key, "zoom").forEach((slider) => { slider.value = 1 })
    this.frame(key)
    this.render()

    const token = this.field(key, "token")[0]
    token.value = ""
    this.status(key, "uploading")
    this.busy(true)
    try {
      const body = new FormData()
      body.append("photo", file)
      const response = await fetch(this.element.dataset.personalizeUploadUrl, {
        method: "POST", body, headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content, Accept: "application/json" }
      })
      const answer = await response.json()
      if (!response.ok) throw new Error(answer.error)

      token.value = answer.token
      this.photos[key].size = { width: answer.width, height: answer.height }
      this.sharpness(key)
    } catch (error) {
      this.status(key, null, error.message)
    } finally {
      this.busy(false)
    }
  }

  zoom(event) {
    const key = event.target.dataset.personalizeZoom
    if (!this.photos[key]) return

    this.photos[key].zoom = +event.target.value
    this.field(key, "zoom").forEach((slider) => { if (slider !== event.target) slider.value = event.target.value })
    this.frame(key)
    this.sharpness(key)
    this.render()
  }

  // A required photo the buyer hasn't added stops adding to the cart there and then, said by the
  // photo's field (a hidden field isn't checked by the browser, and the Platform's answer would
  // come back at the top of the page).
  check = (event) => {
    const missing = [ ...event.target.querySelectorAll("[data-personalize-token][required]") ].find((token) => !token.value)
    if (!missing) return

    event.preventDefault()
    event.stopImmediatePropagation()
    const key = missing.dataset.personalizeToken
    if (!this.photos[key]) this.status(key, "missing")
    this.element.querySelector(`[data-personalize-photo-field="${key}"]`).scrollIntoView({ behavior: "smooth", block: "center" })
  }

  // Whether the photo, as zoomed, has enough pixels for its box's print size (the field's
  // print-pixels, from the Platform; BuyerUpload#sharp_for? there): half of Printify's 300 dots an
  // inch. Without it, a photo under 1000 pixels is small.
  sharpness(key) {
    const { size, zoom } = this.photos[key]
    if (!size || !this.field(key, "token")[0].value) return

    const pixels = JSON.parse(this.element.querySelector(`[data-personalize-photo-field="${key}"]`).dataset.printPixels || "null")
    const sharp = pixels ? Math.min(size.width, size.height * pixels[0] / pixels[1]) / zoom >= pixels[0] * 0.5 : Math.min(size.width, size.height) >= 1000
    this.status(key, sharp ? "ready" : "small")
  }

  // Dragging the buyer's photo in its box moves it the way the finger goes.
  grab = (event) => {
    const key = event.currentTarget.dataset.key
    if (!this.photos[key]) return

    event.currentTarget.setPointerCapture(event.pointerId)
    this.dragging = { key, x: event.clientX, y: event.clientY, box: event.currentTarget.getBoundingClientRect() }
    event.preventDefault()
  }

  move = (event) => {
    if (!this.dragging) return

    const { key, box } = this.dragging
    const photo = this.photos[key]
    photo.x = clamp(photo.x - (event.clientX - this.dragging.x) / (box.width * photo.zoom), 0, 1)
    photo.y = clamp(photo.y - (event.clientY - this.dragging.y) / (box.height * photo.zoom), 0, 1)
    Object.assign(this.dragging, { x: event.clientX, y: event.clientY })
    this.frame(key)
    this.render()
  }

  drop = () => {
    this.dragging = null
  }

  render = () => {
    if (!this.hasPhotoTarget) return

    const source = this.photoTarget.getAttribute("src")
    this.mirrorTargets.forEach((mirror) => { if (mirror.getAttribute("src") !== source) mirror.src = source })
    for (const photo of this.frames()) this.place(photo, source)
  }

  // The layers in this photo's frame, over it.
  place(photo, source) {
    if (!photo.naturalWidth) return

    const frame = { width: photo.clientWidth, height: photo.clientHeight }
    const scale = Math.max(frame.width / photo.naturalWidth, frame.height / photo.naturalHeight)
    const shown = { width: photo.naturalWidth * scale, height: photo.naturalHeight * scale }
    const offset = { left: photo.offsetLeft + (frame.width - shown.width) / 2, top: photo.offsetTop + (frame.height - shown.height) / 2 }
    const holder = photo.closest("[data-personalize-frame]") || photo.parentElement

    this.layerTargets.filter((layer) => holder.contains(layer)).forEach((layer) => {
      const photos = JSON.parse(layer.dataset.photos || "[]")
      const content = { photo: this.picture, choice: this.chosen, color: this.fill, starmap: this.night }[layer.dataset.kind]?.call(this, layer) || this.words(layer)
      layer.hidden = !(content.text || content.url || content.empty || content.color || content.svg) || (photos.length > 0 && !photos.includes(source))
      if (layer.hidden) return

      const box = JSON.parse(layer.dataset.box)
      Object.assign(layer.style, {
        left: `${offset.left + box.x * shown.width}px`, top: `${offset.top + box.y * shown.height}px`,
        width: `${box.w * shown.width}px`, height: `${box.h * shown.height}px`
      })
      switch (layer.dataset.kind) {
        case "photo": this.showPicture(layer, content); break
        case "choice": this.showChosen(layer, content); break
        case "color": layer.style.background = content.color; break
        case "starmap": layer.replaceChildren(content.svg); break
        default: this.showWords(layer, content)
      }
    })
  }

  // A text layer's line: what the buyer typed (or a sample before they type), in their picks.
  words(layer) {
    const key = layer.dataset.key
    const input = key && this.element.querySelector(`[data-personalize-input="${key}"]`)
    if (!input) return { text: layer.dataset.text, font: layer.dataset.font, color: layer.dataset.color }

    const picked = (kind) => this.element.querySelector(`input[name="properties[${key}_${kind}]"]:checked`)?.value
    const typed = input.value.trim()
    return { text: typed || layer.dataset.sample, sample: !typed, font: picked("font") || layer.dataset.font, color: picked("color") || layer.dataset.color }
  }

  // A line of text, a monogram's three letters (the middle one big), or either bent along an arc.
  showWords(layer, { text, font, color, sample }) {
    const line = layer.firstElementChild
    const curve = +layer.dataset.curve || 0
    const monogram = layer.dataset.style === "monogram"
    const letters = monogram ? text.replace(/[^\p{L}]/gu, "").toUpperCase().slice(0, 3) : text
    layer.querySelector("svg")?.remove()
    Object.assign(line.style, { fontFamily: `"${font}"`, color, opacity: sample ? 0.55 : 1 })
    line.hidden = !!curve
    if (curve) return bend(layer, letters, monogram, { font, color, opacity: sample ? 0.55 : 1, upper: line.classList.contains("uppercase") }, curve)

    if (monogram && letters.length === 3) {
      line.replaceChildren(...[ ...letters ].map((letter, index) => Object.assign(document.createElement("span"), { textContent: letter, style: index === 1 ? "" : `font-size: ${SIDE}em` })))
    } else {
      line.textContent = letters
    }
    fit(line, layer)
  }

  // A photo layer's picture: the one the buyer chose (an empty box to fill before they choose), or
  // a line's.
  picture(layer) {
    const key = layer.dataset.key
    if (!key) {
      const [ zoom, x, y ] = (layer.dataset.crop || "1,0.5,0.5").split(",").map(Number)
      return layer.dataset.photo ? { url: layer.dataset.photo, zoom, x, y, filter: layer.dataset.filter } : {}
    }
    const filter = this.element.querySelector(`input[name="properties[${key}_filter]"]:checked`)?.value
    return this.photos[key] ? { ...this.photos[key], filter } : { empty: true }
  }

  // A choice layer's picture: the one the buyer picked (nothing before they pick), or a line's.
  chosen(layer) {
    const key = layer.dataset.key
    if (!key) return { url: layer.dataset.picture }

    const picked = this.element.querySelector(`input[name="properties[${key}]"]:checked`)?.value
    return { url: picked && JSON.parse(layer.dataset.options || "{}")[picked] }
  }

  showChosen(layer, { url }) {
    const image = layer.firstElementChild
    if (image.getAttribute("src") !== url) image.src = url
  }

  // A star map's sky: the day and city the buyer picked (once the stars have loaded), or a line's.
  night(layer) {
    const key = layer.dataset.key
    const value = key ? this.element.querySelector(`[data-personalize-starmap-value="${key}"]`)?.value : layer.dataset.when
    const place = key ? this.element.querySelector(`[data-personalize-starmap-place="${key}"]`)?.value : layer.dataset.place
    const signature = [ value, place, layer.clientWidth ].join("|")
    if (layer.dataset.drawn === signature) return { svg: layer.firstElementChild }

    const svg = sky.draw(value, place, { sky: layer.dataset.sky, ink: layer.dataset.ink, lines: layer.dataset.lines !== "false" })
    if (svg) layer.dataset.drawn = signature
    return { svg }
  }

  // A color layer's color: the one the buyer picked, or a line's.
  fill(layer) {
    const key = layer.dataset.key
    if (!key) return { color: layer.dataset.color }

    return { color: this.element.querySelector(`input[name="properties[${key}]"]:checked`)?.value }
  }

  showPicture(layer, { url, zoom, x, y, empty, filter }) {
    const [ image, placeholder ] = layer.children
    if (placeholder) placeholder.hidden = !empty
    image.hidden = !!empty
    layer.style.cursor = empty ? "" : "move"
    if (empty) return

    if (image.getAttribute("src") !== url) image.src = url
    Object.assign(image.style, { objectPosition: `${x * 100}% ${y * 100}%`, transformOrigin: `${x * 100}% ${y * 100}%`, transform: `scale(${zoom})`,
      filter: { bw: "grayscale(1)", sepia: "sepia(1)" }[filter] || "none" })
  }

  // The framing goes with the line as "zoom,x,y".
  frame(key) {
    const { zoom, x, y } = this.photos[key]
    this.field(key, "crop").forEach((input) => { input.value = [ zoom, x, y ].map((value) => +value.toFixed(3)).join(",") })
  }

  field(key, part) {
    return [ ...this.element.querySelectorAll(`[data-personalize-${part}="${key}"]`) ]
  }

  status(key, state, message) {
    const status = this.element.querySelector(`[data-personalize-photo-field="${key}"] [data-personalize-status]`)
    status.textContent = state ? status.dataset[state] : message
    status.classList.toggle("text-red-600", !state || state === "small" || state === "missing")
  }

  // Adding to the cart waits for the photo to reach the Platform (buttons already off stay off).
  busy(busy) {
    if (busy) {
      this.waiting = [ ...this.element.querySelectorAll("form [type=submit]") ].filter((button) => !button.disabled)
      this.waiting.forEach((button) => { button.disabled = true })
    } else {
      this.waiting?.forEach((button) => { button.disabled = false })
      this.waiting = null
    }
  }

  frames() {
    return this.hasPhotoTarget ? [ this.photoTarget, ...this.mirrorTargets ] : []
  }
}

// A monogram's outer letters, as a share of its middle one (the print uses the same).
const SIDE = 0.72

// The text bent along an arc of `curve` degrees (up: an arch, down: a smile) as long as the text
// itself, then fitted whole into the box, as the print bends it and then fits it.
function bend(layer, letters, monogram, { font, color, opacity, upper }, curve) {
  const ns = "http://www.w3.org/2000/svg"
  const size = 100
  const svg = document.createElementNS(ns, "svg")
  svg.setAttribute("preserveAspectRatio", "xMidYMid meet")
  Object.assign(svg.style, { position: "absolute", inset: 0, width: "100%", height: "100%", overflow: "visible", opacity })
  const textNode = document.createElementNS(ns, "text")
  Object.assign(textNode.style, { fontFamily: `"${font}"`, fill: color, textTransform: upper ? "uppercase" : "none" })
  textNode.setAttribute("font-size", size)
  textNode.setAttribute("text-anchor", "middle")
  const parts = monogram && letters.length === 3 ? [ ...letters ].map((letter, index) => [ letter, index === 1 ? 1 : SIDE ]) : [ [ letters, 1 ] ]
  const spans = parts.map(([ part, share ]) => {
    const span = document.createElementNS(ns, "tspan")
    span.textContent = part
    if (share !== 1) span.setAttribute("font-size", `${SIDE}em`)
    return span
  })
  textNode.append(...spans)
  svg.append(textNode)
  layer.append(svg)

  const angle = Math.abs(curve) * Math.PI / 180
  const radius = Math.max(textNode.getComputedTextLength(), 1) / angle
  const half = angle / 2, outer = radius + size * 0.8
  const path = document.createElementNS(ns, "path")
  path.id = `arc-${Math.random().toString(36).slice(2)}`
  path.setAttribute("fill", "none")
  let box
  if (curve > 0) {
    path.setAttribute("d", `M ${-radius * Math.sin(half)} ${-radius * Math.cos(half)} A ${radius} ${radius} 0 0 1 ${radius * Math.sin(half)} ${-radius * Math.cos(half)}`)
    box = [ -outer * Math.sin(half), -outer, 2 * outer * Math.sin(half), outer - radius * Math.cos(half) + size * 0.3 ]
  } else {
    path.setAttribute("d", `M ${-radius * Math.sin(half)} ${radius * Math.cos(half)} A ${radius} ${radius} 0 0 0 ${radius * Math.sin(half)} ${radius * Math.cos(half)}`)
    const top = (radius - size * 0.8) * Math.cos(half)
    box = [ -(radius + size * 0.3) * Math.sin(half), top, 2 * (radius + size * 0.3) * Math.sin(half), radius + size * 0.3 - top ]
  }
  const along = document.createElementNS(ns, "textPath")
  along.setAttribute("href", `#${path.id}`)
  along.setAttribute("startOffset", "50%")
  along.append(...spans)
  textNode.replaceChildren(along)
  svg.prepend(path)
  svg.setAttribute("viewBox", box.join(" "))
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max)
}

// The largest size, up to the box's height, at which the line fits the box's width (at any size
// of photo, a thumbnail too).
function fit(line, box) {
  const height = box.clientHeight
  line.style.fontSize = `${height}px`
  const wide = line.scrollWidth
  line.style.fontSize = `${wide > box.clientWidth ? height * box.clientWidth / wide * 0.98 : height}px`
}
