import { Controller } from "@hotwired/stimulus"

// Product page: picks the variant that matches the chosen options, shows its price and
// whether it can be bought, and puts its id in the add-to-cart form.
export default class extends Controller {
  static targets = [ "option", "variantId", "price", "compareAtPrice", "saving", "choice", "submit", "unavailable" ]
  static values = { variants: Array }

  connect() {
    this.update()
  }

  update() {
    const chosen = this.chosenOptions()
    const variant = this.variantsValue.find((candidate) => candidate.options.every((value, index) => value === chosen[index]))

    this.markUnavailableChoices(chosen)
    this.choiceTargets.forEach((choice) => {
      const value = chosen[Number(choice.dataset.position)]
      choice.textContent = value ? `: ${value}` : ""
    })
    if (!variant) return this.show(null)
    this.variantIdTarget.value = variant.id
    this.show(variant)
    if (variant.image) this.dispatch("image", { detail: { url: variant.image } })
    this.dispatch("change", { detail: { selection: [ ...variant.options, variant.price ].join(" · ") } })
  }

  // Narrows a long list of values (dozens of colors) to those matching what the buyer types.
  filter(event) {
    const query = event.target.value.trim().toLowerCase()
    this.optionTargets.filter((input) => input.dataset.position === event.target.dataset.position).forEach((input) => {
      input.closest("label").hidden = query !== "" && !input.value.toLowerCase().includes(query) && !input.checked
    })
  }

  chosenOptions() {
    const groups = new Map()
    this.optionTargets.forEach((input) => {
      if (input.checked) groups.set(Number(input.dataset.position), input.value)
    })
    return [ ...groups.keys() ].sort().map((position) => groups.get(position))
  }

  show(variant) {
    const available = Boolean(variant?.available)
    if (variant && this.hasPriceTarget) this.priceTarget.textContent = variant.price
    if (this.hasCompareAtPriceTarget) {
      this.compareAtPriceTarget.textContent = variant?.compare_at_price || ""
      this.compareAtPriceTarget.hidden = !variant?.compare_at_price
    }
    if (this.hasSavingTarget) {
      this.savingTarget.textContent = variant?.saving || ""
      this.savingTarget.hidden = !variant?.saving
    }
    this.submitTarget.disabled = !available
    if (this.hasUnavailableTarget) {
      this.unavailableTarget.hidden = available
      this.unavailableTarget.textContent = variant?.sold_out ? this.unavailableTarget.dataset.soldOut : this.unavailableTarget.dataset.notMade
    }
  }

  // Dims the values that, with the other choices, make a combination that can't be bought.
  markUnavailableChoices(chosen) {
    this.optionTargets.forEach((input) => {
      const position = Number(input.dataset.position)
      const combination = [ ...chosen ]
      combination[position] = input.value
      const buyable = this.variantsValue.some((variant) => variant.available && variant.options.every((value, index) => value === combination[index]))
      input.closest("label")?.classList.toggle("opacity-40", !buyable)
    })
  }
}
