import { Controller } from "@hotwired/stimulus"

// Product photos: clicking a thumbnail shows it as the main photo, and tapping the main photo
// opens it larger.
export default class extends Controller {
  static targets = [ "main", "thumb", "zoom", "zoomImage" ]

  show(event) {
    const thumb = event.currentTarget
    this.mainTarget.src = thumb.dataset.large
    this.thumbTargets.forEach((other) => other.setAttribute("aria-current", String(other === thumb)))
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
    this.thumbTargets.forEach((thumb) => thumb.setAttribute("aria-current", String(thumb.dataset.large === url)))
  }
}
