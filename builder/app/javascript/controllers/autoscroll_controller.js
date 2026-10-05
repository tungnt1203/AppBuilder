import { Controller } from "@hotwired/stimulus"

// Keeps the chat scrolled to the newest message.
export default class extends Controller {
  connect() {
    this.scroll()
    this.observer = new MutationObserver(() => this.scroll())
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    this.observer.disconnect()
  }

  scroll() {
    this.element.scrollTop = this.element.scrollHeight
  }
}
