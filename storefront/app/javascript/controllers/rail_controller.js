import { Controller } from "@hotwired/stimulus"

// A row of cards to swipe (sections/_products, rail): a track under it shows how much is seen and
// where, and the arrows move a card at a time, so a row that runs past the edge reads as more to
// see, not as cut off. Both hide when every card fits.
export default class extends Controller {
  static targets = [ "list", "controls", "thumb", "previous", "next" ]

  connect() {
    this.update()
    this.observer = new ResizeObserver(() => this.update())
    this.observer.observe(this.listTarget)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  previous() {
    this.move(-1)
  }

  next() {
    this.move(1)
  }

  move(direction) {
    const card = this.listTarget.firstElementChild
    const step = card ? card.getBoundingClientRect().width + parseFloat(getComputedStyle(this.listTarget).columnGap || 0) : this.listTarget.clientWidth
    this.listTarget.scrollBy({ left: direction * step, behavior: "smooth" })
  }

  update() {
    const { scrollLeft, scrollWidth, clientWidth } = this.listTarget
    const overflow = scrollWidth - clientWidth
    this.controlsTarget.hidden = overflow <= 2
    if (overflow <= 2) return

    const seen = clientWidth / scrollWidth
    this.thumbTarget.style.width = `${seen * 100}%`
    this.thumbTarget.style.transform = `translateX(${(scrollLeft / overflow) * (1 / seen - 1) * 100}%)`
    this.previousTarget.disabled = scrollLeft <= 2
    this.nextTarget.disabled = scrollLeft >= overflow - 2
  }
}
