import { Controller } from "@hotwired/stimulus"

// Product form: each variant's margin (what's left of the price over the cost), and raising
// every price by a percent at once, rounded to .99 cents the way shops price. Saved with the form.
export default class extends Controller {
  static targets = [ "price", "cost", "margin", "percent" ]

  connect() {
    this.update()
  }

  update() {
    this.priceTargets.forEach((input, index) => {
      const price = parseFloat(input.value)
      const cost = parseFloat(this.costTargets[index]?.value)
      const cell = this.marginTargets[index]
      if (!cell) return
      if (!(price > 0) || Number.isNaN(cost)) return cell.textContent = "–"

      const margin = Math.round((price - cost) / price * 100)
      cell.textContent = `${margin}%`
      cell.classList.toggle("text-red-600", margin <= 0)
      cell.classList.toggle("font-medium", margin <= 0)
    })
  }

  raise() {
    const percent = parseFloat(this.percentTarget.value)
    if (Number.isNaN(percent)) return

    this.priceTargets.forEach((input) => {
      const price = parseFloat(input.value)
      if (!(price > 0)) return
      const raised = Math.max(Math.ceil(price * (1 + percent / 100)) - 0.01, 0.99)
      input.value = raised.toFixed(2)
    })
    this.percentTarget.value = ""
    this.update()
  }
}
