import { Controller } from "@hotwired/stimulus"

// Native <dialog>. Open it with dialog_button, or showModal() from this controller.
export default class extends Controller {
  close() {
    this.element.close()
  }

  backdrop(event) {
    if (event.target === this.element) this.close()
  }
}
