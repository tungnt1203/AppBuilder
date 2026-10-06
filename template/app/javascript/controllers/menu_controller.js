import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "panel", "button" ]

  toggle() {
    const open = this.panelTarget.classList.toggle("hidden") === false
    this.buttonTarget.setAttribute("aria-expanded", String(open))
  }

  close(event) {
    if (this.element.contains(event.target)) return

    this.panelTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  escape(event) {
    if (event.key !== "Escape" || this.panelTarget.classList.contains("hidden")) return

    this.panelTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.buttonTarget.focus()
  }
}
