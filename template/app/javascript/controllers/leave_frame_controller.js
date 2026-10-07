import { Controller } from "@hotwired/stimulus"

// Payment pages (Stripe Checkout) refuse to open inside a frame, such as the app builder's
// preview: there, the form opens them in a new tab instead.
export default class extends Controller {
  connect() {
    if (window.top !== window.self) this.element.target = "_blank"
  }
}
