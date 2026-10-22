import { Controller } from "@hotwired/stimulus"

// What the buyer adds to a product, on its photo where the shop placed it. Each layer is a box in
// fractions of the photo (data-box), laid over the photo as it shows (cropped to fill its frame).
// Text is shrunk to fit its box; a photo fills it, framed by a zoom and the point kept in view
// ("zoom,x,y", as the print will be).
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
    document.fonts.ready.then(this.render)
    this.render()
  }

  disconnect() {
    this.resize.disconnect()
    this.swap.disconnect()
    for (const photo of this.frames()) photo.removeEventListener("load", this.render)
    Object.values(this.photos).forEach(({ url }) => URL.revokeObjectURL(url))
  }

  // An input or a pick changed (the form is inside this controller on the product page).
  update() {
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
      this.status(key, Math.min(answer.width, answer.height) < 1000 ? "small" : "ready")
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
    this.render()
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
      const content = layer.dataset.kind === "photo" ? this.picture(layer) : this.words(layer)
      layer.hidden = !content || !(content.text || content.url || content.empty) || (photos.length > 0 && !photos.includes(source))
      if (layer.hidden) return

      const box = JSON.parse(layer.dataset.box)
      Object.assign(layer.style, {
        left: `${offset.left + box.x * shown.width}px`, top: `${offset.top + box.y * shown.height}px`,
        width: `${box.w * shown.width}px`, height: `${box.h * shown.height}px`
      })
      layer.dataset.kind === "photo" ? this.showPicture(layer, content) : this.showWords(layer, content)
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

  showWords(layer, { text, font, color, sample }) {
    const line = layer.firstElementChild
    line.textContent = text
    Object.assign(line.style, { fontFamily: `"${font}"`, color, opacity: sample ? 0.55 : 1 })
    fit(line, layer)
  }

  // A photo layer's picture: the one the buyer chose (an empty box to fill before they choose), or
  // a line's.
  picture(layer) {
    const key = layer.dataset.key
    if (!key) {
      const [ zoom, x, y ] = (layer.dataset.crop || "1,0.5,0.5").split(",").map(Number)
      return layer.dataset.photo ? { url: layer.dataset.photo, zoom, x, y } : null
    }
    return this.photos[key] || { empty: true }
  }

  showPicture(layer, { url, zoom, x, y, empty }) {
    const [ image, placeholder ] = layer.children
    if (placeholder) placeholder.hidden = !empty
    image.hidden = !!empty
    layer.style.cursor = empty ? "" : "move"
    if (empty) return

    if (image.getAttribute("src") !== url) image.src = url
    Object.assign(image.style, { objectPosition: `${x * 100}% ${y * 100}%`, transformOrigin: `${x * 100}% ${y * 100}%`, transform: `scale(${zoom})` })
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
    status.classList.toggle("text-red-600", !state || state === "small")
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
