import { Controller } from "@hotwired/stimulus"

// Product page on a phone: once the add-to-cart button scrolls out of view, a bar at the bottom
// of the screen keeps it in reach. The bar's button is disabled whenever the main one is (an
// option that's sold out).
export default class extends Controller {
  static targets = [ "button", "bar", "copy", "selection" ]

  connect() {
    this.observer = new IntersectionObserver(() => this.check())
    this.observer.observe(this.buttonTarget)
    // A jump straight back to the top (tapping the phone's status bar) takes the button from
    // above the screen to below it without ever crossing it, so the observer alone misses it.
    this.onScroll = () => { if (!this.pending) this.pending = requestAnimationFrame(() => { this.pending = null; this.check() }) }
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.mirror = new MutationObserver(() => this.copyTarget.disabled = this.buttonTarget.disabled)
    this.mirror.observe(this.buttonTarget, { attributes: true, attributeFilter: [ "disabled" ] })
    this.copyTarget.disabled = this.buttonTarget.disabled
  }

  disconnect() {
    this.observer?.disconnect()
    window.removeEventListener("scroll", this.onScroll)
    this.mirror?.disconnect()
    document.body.classList.remove("pb-20", "md:pb-0")
  }

  // What the button adds: the chosen color and size and its price (variant-picker:change).
  select({ detail: { selection } }) {
    if (this.hasSelectionTarget) this.selectionTarget.textContent = selection
  }

  // Shown only once the main button has scrolled up out of view.
  check() {
    this.toggle(this.buttonTarget.getBoundingClientRect().bottom < 0)
  }

  toggle(show) {
    this.barTarget.hidden = !show
    document.body.classList.toggle("pb-20", show)
    document.body.classList.toggle("md:pb-0", show)
  }
}
