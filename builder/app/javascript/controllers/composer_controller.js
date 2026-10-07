import { Controller } from "@hotwired/stimulus"

// Grows the message box with its content up to its max-height, then scrolls inside it,
// and sends with ⌘↵ or Ctrl↵.
export default class extends Controller {
  static targets = [ "input" ]

  connect() {
    this.resize()
    this.observer = new ResizeObserver(() => this.resize())
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  resize() {
    const input = this.inputTarget
    const width = input.clientWidth
    if (this.height && width === this.width && input.value === this.value) return
    this.width = width
    this.value = input.value

    input.style.height = "auto"
    const max = parseFloat(getComputedStyle(input).maxHeight) || Infinity
    const height = input.scrollHeight
    input.style.height = `${Math.min(height, max)}px`
    input.style.overflowY = height > max ? "auto" : "hidden"
    this.height = height
  }

  submitOnShortcut(event) {
    if (event.key === "Enter" && (event.metaKey || event.ctrlKey) && !event.isComposing) {
      event.preventDefault()
      this.element.requestSubmit()
    }
  }
}
