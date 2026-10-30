import { Controller } from "@hotwired/stimulus"

// The admin's quick search: ⌘K (Ctrl+K) or the button opens it, typing loads the results into
// its frame (a moment after the last key), up and down move through them, Enter opens one.
export default class extends Controller {
  static targets = [ "dialog", "input", "frame", "result" ]
  static values = { url: String }

  open(event) {
    event?.preventDefault()
    if (this.dialogTarget.open) return

    this.dialogTarget.showModal()
    this.inputTarget.select()
    if (!this.frameTarget.src) this.load()
  }

  close() {
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.load(), 180)
  }

  load() {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", this.inputTarget.value)
    this.frameTarget.src = url.toString()
  }

  navigate(event) {
    const results = this.resultTargets
    if (!results.length) return

    const current = results.indexOf(document.activeElement)
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      const next = current === -1 ? (step === 1 ? 0 : results.length - 1) : (current + step + results.length) % results.length
      results[next].focus()
    } else if (event.key === "Enter" && event.target === this.inputTarget) {
      event.preventDefault()
      results[0].click()
    }
  }

  // Closed before Turbo caches the page, so going back doesn't show it open.
  disconnect() {
    clearTimeout(this.timer)
    if (this.dialogTarget.open) this.dialogTarget.close()
  }
}
