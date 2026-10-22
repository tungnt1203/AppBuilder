import { Controller } from "@hotwired/stimulus"

// Where a buyer's text sits on a product's photos: drag on the photo to draw its box (or drag the
// box to move it). The box is kept as fractions of the photo (x, y, w, h), and a sample line shows
// in the chosen font, color and alignment, shrunk to fit as it will be in the storefront.
export default class extends Controller {
  static targets = [ "stage", "photo", "box", "sample", "x", "y", "w", "h", "font", "color", "align", "uppercase" ]

  connect() {
    this.photoTarget.complete ? this.render() : this.photoTarget.addEventListener("load", () => this.render(), { once: true })
  }

  start(event) {
    const point = this.point(event)
    const box = this.current()
    this.stageTarget.setPointerCapture(event.pointerId)
    if (box && point.x >= box.x && point.x <= box.x + box.w && point.y >= box.y && point.y <= box.y + box.h) {
      this.moving = { from: point, box }
    } else {
      this.drawing = point
      this.set({ x: point.x, y: point.y, w: 0, h: 0 })
    }
  }

  drag(event) {
    if (!this.moving && !this.drawing) return
    const point = this.point(event)
    if (this.moving) {
      const { from, box } = this.moving
      this.set({ ...box, x: clamp(box.x + point.x - from.x, 0, 1 - box.w), y: clamp(box.y + point.y - from.y, 0, 1 - box.h) })
    } else {
      const start = this.drawing
      this.set({ x: Math.min(start.x, point.x), y: Math.min(start.y, point.y), w: Math.abs(point.x - start.x), h: Math.abs(point.y - start.y) })
    }
  }

  stop() {
    this.moving = this.drawing = null
  }

  clear() {
    this.set({ x: 0, y: 0, w: 0, h: 0 })
  }

  // A photo ticked to show the text on: the box is drawn on it.
  use(event) {
    if (event.target.checked && event.target.dataset.large) this.photoTarget.src = event.target.dataset.large
  }

  restyle() {
    this.render()
  }

  point(event) {
    const rect = this.photoTarget.getBoundingClientRect()
    return { x: clamp((event.clientX - rect.left) / rect.width, 0, 1), y: clamp((event.clientY - rect.top) / rect.height, 0, 1) }
  }

  current() {
    const box = { x: +this.xTarget.value, y: +this.yTarget.value, w: +this.wTarget.value, h: +this.hTarget.value }
    return box.w > 0 && box.h > 0 ? box : null
  }

  set(box) {
    for (const side of [ "x", "y", "w", "h" ]) this[`${side}Target`].value = box[side] ? box[side].toFixed(4) : ""
    this.render()
  }

  render() {
    const box = this.current()
    this.boxTarget.hidden = !box
    if (!box) return

    Object.assign(this.boxTarget.style, { left: `${box.x * 100}%`, top: `${box.y * 100}%`, width: `${box.w * 100}%`, height: `${box.h * 100}%` })
    Object.assign(this.sampleTarget.style, {
      fontFamily: `"${this.fontTarget.value}"`, color: this.colorTarget.value, textAlign: this.alignTarget.value,
      textTransform: this.uppercaseTarget.checked ? "uppercase" : "none"
    })
    fit(this.sampleTarget, this.boxTarget)
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
