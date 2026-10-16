import { Controller } from "@hotwired/stimulus"

// One checkbox for a group of them: a product's box ticks all its variants, and shows when only
// some are ticked.
export default class extends Controller {
  static targets = [ "all", "item" ]

  connect() {
    this.sync()
  }

  toggle() {
    this.itemTargets.forEach(item => item.checked = this.allTarget.checked)
    this.sync()
  }

  sync() {
    const checked = this.itemTargets.filter(item => item.checked).length
    this.allTarget.checked = checked > 0 && checked === this.itemTargets.length
    this.allTarget.indeterminate = checked > 0 && checked < this.itemTargets.length
  }
}
