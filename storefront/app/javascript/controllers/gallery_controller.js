import { Controller } from "@hotwired/stimulus"

// Product photos: clicking a thumbnail (or the arrows on the photo) shows it as the main photo,
// and tapping the main photo opens it larger.
export default class extends Controller {
  static targets = [ "main", "thumb", "zoom", "zoomImage", "counter" ]

  show(event) {
    this.select(event.currentTarget)
  }

  previous() {
    this.move(-1)
  }

  next() {
    this.move(1)
  }

  move(by) {
    const thumbs = this.thumbTargets
    if (thumbs.length < 2) return
    const current = Math.max(0, thumbs.findIndex((thumb) => thumb.getAttribute("aria-current") === "true"))
    this.select(thumbs[(current + by + thumbs.length) % thumbs.length])
  }

  select(thumb) {
    this.mainTarget.src = thumb.dataset.large
    this.mark((other) => other === thumb)
    const strip = thumb.parentElement // its own row only: the page stays where it is
    strip.scrollTo({ left: thumb.offsetLeft - (strip.clientWidth - thumb.clientWidth) / 2, behavior: "smooth" })
  }

  // Which thumbnail is showing, and "2 / 5" on the photo.
  mark(isCurrent) {
    this.thumbTargets.forEach((thumb) => thumb.setAttribute("aria-current", String(isCurrent(thumb))))
    if (!this.hasCounterTarget) return
    const index = this.thumbTargets.findIndex((thumb) => thumb.getAttribute("aria-current") === "true")
    if (index >= 0) this.counterTarget.textContent = `${index + 1} / ${this.thumbTargets.length}`
  }

  // The main photo, as large as the screen allows, to check the print.
  zoom() {
    if (!this.hasZoomTarget) return
    this.zoomImageTarget.src = this.mainTarget.currentSrc || this.mainTarget.src
    this.zoomTarget.showModal()
  }

  closeZoom() {
    this.zoomTarget.close()
  }

  // The photo of the color the buyer picked (variant-picker:image).
  showImage({ detail: { url } }) {
    if (!this.hasMainTarget) return
    this.mainTarget.src = url
    this.mark((thumb) => thumb.dataset.large === url)
  }
}
