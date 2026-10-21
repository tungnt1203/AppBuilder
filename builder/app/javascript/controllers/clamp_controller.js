import { Controller } from "@hotwired/stimulus"

// A long message shows its first lines and a "Show more" button, so the chat under it stays in
// view. Live page refreshes morph the DOM, so the owner's choice is kept across them.
export default class extends Controller {
  static targets = [ "text", "toggle" ]

  connect() {
    this.keep = (event) => {
      if (event.target === this.element && event.detail.attributeName === "data-expanded") event.preventDefault()
    }
    this.element.addEventListener("turbo:before-morph-attribute", this.keep)
    this.render()
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-morph-attribute", this.keep)
  }

  toggle() {
    this.element.toggleAttribute("data-expanded")
    this.render()
  }

  render() {
    const expanded = this.element.hasAttribute("data-expanded")
    this.textTarget.classList.toggle("is-clamped", !expanded)
    const overflows = this.textTarget.scrollHeight > this.textTarget.clientHeight + 1
    this.toggleTarget.hidden = !expanded && !overflows
    this.toggleTarget.textContent = expanded ? "Show less" : "Show more"
  }
}
