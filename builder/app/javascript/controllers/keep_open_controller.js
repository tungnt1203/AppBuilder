import { Controller } from "@hotwired/stimulus"

// Live page refreshes morph the DOM from the server's HTML, which would close
// a <details> the owner opened. This keeps whatever they chose. Menus
// (dismissible) also close on Escape or a click outside, like any menu.
export default class extends Controller {
  static values = { dismissible: Boolean }

  connect() {
    this.keep = (event) => {
      if (event.target === this.element && event.detail.attributeName === "open") event.preventDefault()
    }
    this.element.addEventListener("turbo:before-morph-attribute", this.keep)

    if (this.dismissibleValue) {
      this.dismiss = (event) => {
        if (!this.element.open) return
        if (event.type === "keydown" ? event.key === "Escape" : !this.element.contains(event.target)) this.element.open = false
      }
      document.addEventListener("click", this.dismiss)
      document.addEventListener("keydown", this.dismiss)
    }
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-morph-attribute", this.keep)
    document.removeEventListener("click", this.dismiss)
    document.removeEventListener("keydown", this.dismiss)
  }
}
