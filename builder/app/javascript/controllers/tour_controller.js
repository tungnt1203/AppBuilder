import { Controller } from "@hotwired/stimulus"
import { driver } from "driver.js"

// A short tour of the studio, from one marked element to the next. Each stop is an element
// with data-tour-step (its order), data-tour-title, data-tour-text and optionally
// data-tour-side (top, right, bottom, left) and data-tour-align; stops that aren't on
// screen (hidden on phones, say) are left out. It starts by itself on someone's first visit
// and, finished or closed, tells the builder not to start again.
export default class extends Controller {
  static values = { auto: Boolean, seenUrl: String }

  connect() {
    if (this.autoValue) this.autoStart = setTimeout(() => this.start(), 600)

    // The page is redrawn by morphing while the agent works; keep the tour's own nodes and
    // the classes it put on the page.
    this.keepNodes = (event) => {
      if (this.driver?.isActive() && event.target.className?.toString().startsWith("driver-")) event.preventDefault()
    }
    this.restore = () => {
      if (!this.driver?.isActive()) return
      document.body.classList.add("driver-active", "driver-fade")
      this.driver.getActiveElement()?.classList.add("driver-active-element")
      this.driver.refresh()
    }
    document.addEventListener("turbo:before-morph-element", this.keepNodes)
    document.addEventListener("turbo:morph", this.restore)
  }

  disconnect() {
    clearTimeout(this.autoStart)
    document.removeEventListener("turbo:before-morph-element", this.keepNodes)
    document.removeEventListener("turbo:morph", this.restore)
    this.driver?.destroy()
  }

  start() {
    const steps = this.steps()
    if (steps.length === 0) return

    this.driver?.destroy()
    this.driver = driver({
      steps,
      animate: true,
      smoothScroll: true,
      showProgress: true,
      progressText: "{{current}} of {{total}}",
      nextBtnText: "Next",
      prevBtnText: "Back",
      doneBtnText: "Start building",
      popoverClass: "tour",
      stagePadding: 6,
      stageRadius: 14,
      overlayColor: "rgb(6 30 34)",
      overlayOpacity: 0.45,
      disableActiveInteraction: true,
      onDestroyed: () => this.seen()
    })
    this.driver.drive()
  }

  steps() {
    return Array.from(document.querySelectorAll("[data-tour-step]"))
      .filter((element) => element.getClientRects().length > 0)
      .sort((a, b) => Number(a.dataset.tourStep) - Number(b.dataset.tourStep))
      .map((element) => ({
        element,
        popover: {
          title: element.dataset.tourTitle,
          description: element.dataset.tourText,
          side: element.dataset.tourSide,
          align: element.dataset.tourAlign
        }
      }))
  }

  seen() {
    if (!this.autoValue) return

    this.autoValue = false
    const token = document.querySelector("meta[name=csrf-token]")?.content
    fetch(this.seenUrlValue, { method: "POST", headers: { "X-CSRF-Token": token } })
  }
}
