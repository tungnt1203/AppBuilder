import { Controller } from "@hotwired/stimulus"

// Copies a reply as the agent wrote it (Markdown) and shows a tick on the button for a moment.
export default class extends Controller {
  static values = { text: String }

  async copy(event) {
    const button = event.currentTarget
    try {
      await navigator.clipboard.writeText(this.textValue)
    } catch {
      // Pages not served over HTTPS have no clipboard API, and it refuses an unfocused page.
      const scratch = Object.assign(document.createElement("textarea"), { value: this.textValue })
      scratch.style.cssText = "position: fixed; opacity: 0"
      document.body.append(scratch)
      scratch.select()
      const copied = document.execCommand("copy")
      scratch.remove()
      if (!copied) return
    }
    button.dataset.copied = ""
    clearTimeout(this.timer)
    this.timer = setTimeout(() => delete button.dataset.copied, 1500)
  }
}
