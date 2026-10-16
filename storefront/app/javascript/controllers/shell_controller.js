import { Controller } from "@hotwired/stimulus"

// Mobile drawer for the app sidebar. On large screens the sidebar stays put.
export default class extends Controller {
  static targets = [ "nav", "backdrop", "menu" ]

  toggle() {
    const closed = this.navTarget.classList.toggle("max-lg:hidden")
    this.backdropTarget.classList.toggle("hidden", closed)
    this.menuTarget.setAttribute("aria-expanded", String(!closed))
  }

  close() {
    this.navTarget.classList.add("max-lg:hidden")
    this.backdropTarget.classList.add("hidden")
    this.menuTarget.setAttribute("aria-expanded", "false")
  }

  follow(event) {
    if (event.target.closest("a")) this.close()
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
