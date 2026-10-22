import { Controller } from "@hotwired/stimulus"

// The buyer's text on a product photo, where the shop placed it. Each layer is a box in fractions
// of the photo (data-box), laid over the photo as it shows (cropped to fill its frame), its text
// shrunk to fit the box. On the product page the text follows what the buyer types and the font
// and color they pick, and shows only on the photos the shop chose (data-photos, none: all).
// On a cart or order line the layer carries its text, font and color. A smaller copy of the photo
// (a "mirror", by the field on phones, where the photo has scrolled away) shows the same photo.
export default class extends Controller {
  static targets = [ "photo", "mirror", "layer" ]

  connect() {
    this.resize = new ResizeObserver(() => this.render())
    this.swap = new MutationObserver(() => this.render())
    this.swap.observe(this.photoTarget, { attributes: true, attributeFilter: [ "src" ] })
    for (const photo of [ this.photoTarget, ...this.mirrorTargets ]) {
      this.resize.observe(photo)
      photo.addEventListener("load", this.render)
    }
    document.fonts.ready.then(this.render)
    this.render()
  }

  disconnect() {
    this.resize.disconnect()
    this.swap.disconnect()
    for (const photo of [ this.photoTarget, ...this.mirrorTargets ]) photo.removeEventListener("load", this.render)
  }

  // An input or a pick changed (the form is inside this controller on the product page).
  update() {
    this.render()
  }

  render = () => {
    const source = this.photoTarget.getAttribute("src")
    this.mirrorTargets.forEach((mirror) => { if (mirror.getAttribute("src") !== source) mirror.src = source })
    for (const photo of [ this.photoTarget, ...this.mirrorTargets ]) this.place(photo, source)
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
      const { text, font, color, sample } = this.content(layer)
      layer.hidden = !text || (photos.length > 0 && !photos.includes(source))
      if (layer.hidden) return

      const box = JSON.parse(layer.dataset.box)
      Object.assign(layer.style, {
        left: `${offset.left + box.x * shown.width}px`, top: `${offset.top + box.y * shown.height}px`,
        width: `${box.w * shown.width}px`, height: `${box.h * shown.height}px`
      })
      const line = layer.firstElementChild
      line.textContent = text
      Object.assign(line.style, { fontFamily: `"${font}"`, color, opacity: sample ? 0.55 : 1 })
      fit(line, layer)
    })
  }

  // What a layer shows: what the buyer typed (or a sample before they type), in their picks.
  content(layer) {
    const key = layer.dataset.key
    const input = key && this.element.querySelector(`[data-personalize-input="${key}"]`)
    if (!input) return { text: layer.dataset.text, font: layer.dataset.font, color: layer.dataset.color }

    const picked = (kind) => this.element.querySelector(`input[name="properties[${key}_${kind}]"]:checked`)?.value
    const typed = input.value.trim()
    return { text: typed || layer.dataset.sample, sample: !typed, font: picked("font") || layer.dataset.font, color: picked("color") || layer.dataset.color }
  }
}

// The largest size, up to the box's height, at which the line fits the box's width (at any size
// of photo, a thumbnail too).
function fit(line, box) {
  const height = box.clientHeight
  line.style.fontSize = `${height}px`
  const wide = line.scrollWidth
  line.style.fontSize = `${wide > box.clientWidth ? height * box.clientWidth / wide * 0.98 : height}px`
}
