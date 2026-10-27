import { Controller } from "@hotwired/stimulus"

// Sends its form as soon as something in it is picked or changed: files chosen in a file field,
// a name typed and left. A form already sending isn't sent twice.
export default class extends Controller {
  submit() {
    if (this.element.matches("[aria-busy]")) return
    this.element.requestSubmit()
  }

  // Pictures dropped on the form go in its file field and are sent.
  drop(event) {
    event.preventDefault()
    this.element.classList.remove("is-dropping")
    const input = this.element.querySelector("input[type=file]")
    if (!input || !event.dataTransfer?.files.length) return

    input.files = event.dataTransfer.files
    this.submit()
  }

  dragOver(event) {
    event.preventDefault()
    this.element.classList.add("is-dropping")
  }

  dragLeave(event) {
    if (!this.element.contains(event.relatedTarget)) this.element.classList.remove("is-dropping")
  }
}
