import { Controller } from "@hotwired/stimulus"

// Stripe's Payment Element for a card order: mounts it with the order's PaymentIntent, and
// confirms it, after which Stripe sends the buyer to the order's page (or shows them 3-D Secure first).
export default class extends Controller {
  static targets = [ "element", "error", "button" ]
  static values = { publishableKey: String, clientSecret: String, returnUrl: String, email: String, billing: Object }

  async connect() {
    const Stripe = await this.stripe()
    if (!Stripe) return this.showError("The payment form couldn't load. Check your connection and reload the page.")

    this.client = Stripe(this.publishableKeyValue)
    this.elements = this.client.elements({ clientSecret: this.clientSecretValue, appearance: this.appearance() })
    // The billing details start from the shipping address (its country, not the browser's).
    const billingDetails = { ...this.billingValue, email: this.emailValue }
    this.paymentElement = this.elements.create("payment", { defaultValues: { billingDetails } })
    this.paymentElement.mount(this.elementTarget)
    this.paymentElement.on("ready", () => { this.buttonTarget.disabled = false })
  }

  disconnect() {
    this.paymentElement?.destroy()
  }

  async pay(event) {
    event.preventDefault()
    if (!this.client) return

    this.buttonTarget.disabled = true
    this.errorTarget.hidden = true
    const { error } = await this.client.confirmPayment({ elements: this.elements, confirmParams: { return_url: this.returnUrlValue } })
    // Only here when the payment didn't go through: a declined card, a wrong number.
    this.showError(error.message)
    this.buttonTarget.disabled = false
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  // The form in the theme's colors and corners, so it reads on a dark theme too.
  appearance() {
    const style = getComputedStyle(document.documentElement)
    const color = name => this.rgb(style.getPropertyValue(`--color-${name}`).trim())
    return {
      theme: "stripe",
      variables: {
        colorPrimary: color("brand-600"), colorBackground: color("surface"), colorText: color("ink"),
        colorTextSecondary: color("muted"), borderRadius: style.getPropertyValue("--radius-lg").trim() || "6px"
      }
    }
  }

  // Stripe takes rgb and hex, not the oklch a theme may use: let a canvas turn one into the other.
  rgb(value) {
    if (!value) return undefined
    const context = document.createElement("canvas").getContext("2d", { willReadFrequently: true })
    context.fillStyle = value
    context.fillRect(0, 0, 1, 1)
    const [ red, green, blue ] = context.getImageData(0, 0, 1, 1).data
    return `rgb(${red}, ${green}, ${blue})`
  }

  // js.stripe.com loads on its own (async in the head); wait for it a little.
  async stripe() {
    for (let tries = 0; tries < 50 && !window.Stripe; tries++) await new Promise(resolve => setTimeout(resolve, 100))
    return window.Stripe
  }
}
