import { Controller } from "@hotwired/stimulus"

// Fills the new app form with one of the ideas under it.
export default class extends Controller {
  static targets = [ "request", "name" ]

  use({ params: { name, request } }) {
    this.nameTarget.value = name
    this.requestTarget.value = request
    this.requestTarget.dispatchEvent(new Event("input"))
    this.requestTarget.focus()
  }
}
