import { Controller } from "@hotwired/stimulus"

// Reloads the preview iframe on demand and whenever the server bumps the version
// (after setup and after each agent turn restarts the preview server).
export default class extends Controller {
  static values = { version: Number }

  versionValueChanged(_version, previous) {
    if (previous !== undefined) this.reload()
  }

  reload() {
    const frame = document.getElementById("preview-frame")
    if (frame) frame.src = frame.src
  }
}
