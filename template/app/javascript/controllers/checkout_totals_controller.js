import { Controller } from "@hotwired/stimulus"

// Reloads the checkout's totals when the address or the way to pay changes: shipping from
// Printify depends on where the order goes.
export default class extends Controller {
  static targets = [ "frame" ]
  static values = { url: String }
  static fields = [ "shipping_country", "shipping_region", "shipping_postal_code", "payment_method" ]

  refresh(event) {
    const name = event.target.name?.match(/^checkout\[(\w+)\]$/)?.[1]
    if (!this.constructor.fields.includes(name)) return

    const data = new FormData(this.element)
    const params = new URLSearchParams()
    this.constructor.fields.forEach(field => {
      const value = data.get(`checkout[${field}]`)
      if (value) params.set(field, value)
    })
    const url = new URL(`${this.urlValue}?${params}`, window.location.href).href
    if (this.frameTarget.src !== url) this.frameTarget.src = url
  }
}
