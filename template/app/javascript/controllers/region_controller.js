import { Controller } from "@hotwired/stimulus"

// The state or province: a list for the countries whose carriers need its code (the US, Canada,
// Australia), where the postal code is needed too, and a text field for the rest.
export default class extends Controller {
  static targets = [ "country", "select", "input", "postalCode" ]
  static values = { names: Object }

  update() {
    const regions = this.namesValue[this.countryTarget.value]
    const choose = this.selectTarget.options[0]?.text || ""

    if (regions) {
      this.selectTarget.replaceChildren(new Option(choose, ""), ...Object.entries(regions).map(([ code, name ]) => new Option(name, code)))
    }
    this.selectTarget.hidden = this.selectTarget.disabled = !regions
    this.inputTarget.hidden = this.inputTarget.disabled = !!regions
    this.postalCodeTarget.required = !!regions
  }
}
