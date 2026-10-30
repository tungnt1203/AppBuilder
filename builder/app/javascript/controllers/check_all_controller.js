import { Controller } from "@hotwired/stimulus"

// A box that ticks every item under it, and shows how many are ticked: the variants of a product
// in a promotion, the rows of a list for a bulk action (its bar shows once one is ticked).
export default class extends Controller {
  static targets = [ "all", "item", "bar", "count" ]

  connect() {
    this.sync()
  }

  toggle() {
    this.itemTargets.forEach((item) => { item.checked = this.allTarget.checked })
    this.sync()
  }

  sync() {
    const ticked = this.itemTargets.filter((item) => item.checked).length
    if (this.hasAllTarget) {
      this.allTarget.checked = ticked > 0 && ticked === this.itemTargets.length
      this.allTarget.indeterminate = ticked > 0 && ticked < this.itemTargets.length
    }
    if (this.hasBarTarget) this.barTarget.hidden = ticked === 0
    if (this.hasCountTarget) this.countTarget.textContent = this.countTarget.dataset.template.replace("%{count}", ticked)
  }
}
