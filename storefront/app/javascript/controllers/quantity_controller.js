import { Controller } from "@hotwired/stimulus"

// A quantity field with − and + beside it (product page, cart): each press moves the number by one
// within the field's min and max, and fires "change" so a cart line saves itself (autosubmit).
export default class extends Controller {
  static targets = [ "field" ]

  decrease() {
    this.step(-1)
  }

  increase() {
    this.step(1)
  }

  step(by) {
    const field = this.fieldTarget
    const min = field.min === "" ? 0 : Number(field.min)
    const max = field.max === "" ? Infinity : Number(field.max)
    const value = Math.min(max, Math.max(min, (Number(field.value) || 0) + by))
    if (value === Number(field.value)) return

    field.value = value
    field.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
