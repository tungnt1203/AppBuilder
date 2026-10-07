import { Controller } from "@hotwired/stimulus"

// Copies the source's value and says so on the button for a moment.
export default class extends Controller {
  static targets = [ "source", "button" ]

  select() {
    this.sourceTarget.select()
  }

  async copy() {
    this.sourceTarget.select()
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
    } catch {
      document.execCommand("copy") // pages not served over HTTPS have no clipboard API
    }
    const label = this.buttonTarget.textContent
    this.buttonTarget.textContent = "Copied"
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { this.buttonTarget.textContent = label }, 1500)
  }
}
