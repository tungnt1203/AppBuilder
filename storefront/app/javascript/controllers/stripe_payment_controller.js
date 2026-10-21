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
    this.elements = this.client.elements({ clientSecret: this.clientSecretValue })
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

  // js.stripe.com loads on its own (async in the head); wait for it a little.
  async stripe() {
    for (let tries = 0; tries < 50 && !window.Stripe; tries++) await new Promise(resolve => setTimeout(resolve, 100))
    return window.Stripe
  }
}
