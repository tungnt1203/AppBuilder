import { Controller } from "@hotwired/stimulus"

// Shows only the fields that go with the chosen option of a select: a discount's percent off for
// a percentage, its amount for an amount off. Each field lists its options in data-show-for.
export default class extends Controller {
  static targets = [ "select", "field" ]

  connect() {
    this.update()
  }

  update() {
    const value = this.selectTarget.value
    this.fieldTargets.forEach(field => {
      field.hidden = !field.dataset.showFor.split(" ").includes(value)
    })
  }
}
