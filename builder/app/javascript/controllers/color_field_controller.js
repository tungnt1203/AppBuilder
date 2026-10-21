import { Controller } from "@hotwired/stimulus"

// A color setting: a swatch to pick from and the hex code beside it, kept in step. Emptying the
// code leaves the setting unset (the theme's own color).
export default class extends Controller {
  static targets = [ "picker", "code" ]

  connect() {
    this.show()
  }

  pick() {
    this.codeTarget.value = this.pickerTarget.value
  }

  show() {
    if (/^#[0-9a-f]{6}$/i.test(this.codeTarget.value)) this.pickerTarget.value = this.codeTarget.value
  }
}
