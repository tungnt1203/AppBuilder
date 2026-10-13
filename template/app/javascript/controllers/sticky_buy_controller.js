import { Controller } from "@hotwired/stimulus"

// Product page on a phone: once the add-to-cart button scrolls out of view, a bar at the bottom
// of the screen keeps it in reach. The bar's button is disabled whenever the main one is (an
// option that's sold out).
export default class extends Controller {
  static targets = [ "button", "bar", "copy" ]

  connect() {
    this.observer = new IntersectionObserver(([ entry ]) => this.toggle(!entry.isIntersecting && entry.boundingClientRect.top < 0))
    this.observer.observe(this.buttonTarget)
    this.mirror = new MutationObserver(() => this.copyTarget.disabled = this.buttonTarget.disabled)
    this.mirror.observe(this.buttonTarget, { attributes: true, attributeFilter: [ "disabled" ] })
    this.copyTarget.disabled = this.buttonTarget.disabled
  }

  disconnect() {
    this.observer?.disconnect()
    this.mirror?.disconnect()
    document.body.classList.remove("pb-20", "md:pb-0")
  }

  toggle(show) {
    this.barTarget.hidden = !show
    document.body.classList.toggle("pb-20", show)
    document.body.classList.toggle("md:pb-0", show)
  }
}
