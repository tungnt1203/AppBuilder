import { Controller } from "@hotwired/stimulus"

// The state or province: a list for the countries whose carriers need its code (the US, Canada,
// Australia), where the postal code is needed too, and a text field for the rest. In the US, a
// ZIP code fills in the city and state (ZipCodesController).
export default class extends Controller {
  static targets = [ "country", "select", "input", "postalCode", "city" ]
  static values = { names: Object, lookupUrl: String }

  update() {
    const regions = this.namesValue[this.countryTarget.value]
    const choose = this.selectTarget.options[0]?.text || ""

    if (regions) {
      this.selectTarget.replaceChildren(new Option(choose, ""), ...Object.entries(regions).map(([ code, name ]) => new Option(name, code)))
    }
    this.selectTarget.hidden = this.selectTarget.disabled = !regions
    this.inputTarget.hidden = this.inputTarget.disabled = !!regions
    this.postalCodeTarget.required = !!regions
    this.postalCodeTarget.inputMode = this.countryTarget.value === "US" ? "numeric" : "text"
  }

  async lookup() {
    const zip = this.postalCodeTarget.value.trim().slice(0, 5)
    if (this.countryTarget.value !== "US" || !/^\d{5}$/.test(zip) || zip === this.lookedUp) return
    this.lookedUp = zip

    const response = await fetch(this.lookupUrlValue.replace("ZIP", zip), { headers: { Accept: "application/json" } }).catch(() => null)
    if (!response?.ok || zip !== this.postalCodeTarget.value.trim().slice(0, 5)) return
    const { state, city } = await response.json()

    // A city the buyer typed themselves stays; one filled in from an earlier ZIP is replaced.
    if (this.hasCityTarget && (!this.cityTarget.value || this.cityTarget.value === this.filledCity)) {
      this.cityTarget.value = this.filledCity = city
    }
    if ([ ...this.selectTarget.options ].some((option) => option.value === state)) {
      this.selectTarget.value = state
      this.selectTarget.dispatchEvent(new Event("change", { bubbles: true })) // the totals reload with Printify's shipping
    }
  }
}
