import { Controller } from "@hotwired/stimulus"

// Grows the message box with its content and sends with ⌘↵ or Ctrl↵.
export default class extends Controller {
  static targets = [ "input" ]

  connect() {
    this.resize()
  }

  resize() {
    const input = this.inputTarget
    input.style.height = "auto"
    input.style.height = `${input.scrollHeight}px`
  }

  submitOnShortcut(event) {
    if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
      event.preventDefault()
      this.element.requestSubmit()
    }
  }
}
