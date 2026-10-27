import { Controller } from "@hotwired/stimulus"

// A row in the chats menu: its name, or a box to rename it, or a word of confirmation
// before it's deleted. Escape goes back to the name.
export default class extends Controller {
  static targets = [ "input", "cancel" ]

  rename() {
    this.element.dataset.mode = "rename"
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  confirm() {
    this.element.dataset.mode = "confirm"
    this.cancelTarget.focus()
  }

  cancel(event) {
    if (!this.element.dataset.mode) return
    event.preventDefault()
    event.stopPropagation() // Escape closes the row's editing, not the whole menu
    delete this.element.dataset.mode
    this.inputTarget.value = this.inputTarget.defaultValue
    this.element.querySelector(".chat-tool")?.focus()
  }
}
