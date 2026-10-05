import { Controller } from "@hotwired/stimulus"

// Sends the message with ⌘↵ or Ctrl↵.
export default class extends Controller {
  submitOnShortcut(event) {
    if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
      event.preventDefault()
      this.element.requestSubmit()
    }
  }
}
