import { Controller } from "@hotwired/stimulus"

// Shows a <time datetime="…"> in the buyer's own time zone: "October 21, 2026 at 8:55 AM".
export default class extends Controller {
  static values = { dateOnly: Boolean }

  connect() {
    const time = new Date(this.element.getAttribute("datetime"))
    if (isNaN(time)) return

    const options = this.dateOnlyValue ? { dateStyle: "long" } : { dateStyle: "long", timeStyle: "short" }
    this.element.textContent = new Intl.DateTimeFormat("en-US", options).format(time)
  }
}
