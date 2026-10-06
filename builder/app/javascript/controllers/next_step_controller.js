import { Controller } from "@hotwired/stimulus"

// Puts a suggested next request in the message box, ready to send or change.
export default class extends Controller {
  use(event) {
    const input = document.getElementById("message_body")
    if (!input || input.disabled) return

    input.value = event.currentTarget.textContent.trim()
    input.dispatchEvent(new Event("input"))
    input.focus()
    input.setSelectionRange(input.value.length, input.value.length)
  }
}
