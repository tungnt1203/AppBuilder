import { Controller } from "@hotwired/stimulus"

// Where a choice field's pictures come from: the product's own (ticked one by one) or one of
// the shop's sets, shown as it is.
export default class extends Controller {
  static targets = [ "select", "set", "own" ]

  show() {
    const picked = this.selectTarget.value
    this.setTargets.forEach((set) => { set.hidden = set.dataset.set !== picked })
    this.ownTarget.hidden = picked !== ""
  }
}
