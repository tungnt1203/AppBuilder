import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "panel", "button" ]

  toggle() {
    const open = this.panelTarget.classList.toggle("hidden") === false
    this.buttonTarget.setAttribute("aria-expanded", String(open))
    if (open) this.panelTarget.querySelector("[data-menu-focus]")?.focus() // a search opens ready to type
  }

  close(event) {
    if (this.element.contains(event.target)) return

    this.hide()
  }

  escape(event) {
    if (event.key !== "Escape" || this.panelTarget.classList.contains("hidden")) return

    this.hide()
    this.buttonTarget.focus()
  }

  // Closed before Turbo caches the page, so going back doesn't show the menu still open.
  hide() {
    this.panelTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }
}
