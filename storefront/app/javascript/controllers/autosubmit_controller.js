import { Controller } from "@hotwired/stimulus"

// Submits its form when a field changes (cart quantities, sort order, filters).
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
