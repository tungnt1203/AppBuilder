import { Controller } from "@hotwired/stimulus"

// Live page refreshes morph the DOM from the server's HTML, which would close
// a <details> the owner opened. This keeps whatever they chose.
export default class extends Controller {
  connect() {
    this.keep = (event) => {
      if (event.target === this.element && event.detail.attributeName === "open") event.preventDefault()
    }
    this.element.addEventListener("turbo:before-morph-attribute", this.keep)
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-morph-attribute", this.keep)
  }
}
