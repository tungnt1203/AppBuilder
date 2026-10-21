import { Controller } from "@hotwired/stimulus"

// Reloads a turbo frame every few seconds while it's on the page.
export default class extends Controller {
  static values = { every: { type: Number, default: 15000 } }

  connect() {
    this.timer = setInterval(() => this.element.reload(), this.everyValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }
}
