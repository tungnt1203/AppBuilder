import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { id: String }

  open() {
    const dialog = document.getElementById(this.idValue)
    if (dialog && !dialog.open) dialog.showModal()
  }
}
