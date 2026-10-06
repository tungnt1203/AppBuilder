import { Controller } from "@hotwired/stimulus"

// Keeps the chat scrolled to the newest message, unless the owner scrolled up
// to read something; reaching the bottom again turns it back on.
export default class extends Controller {
  static SLACK = 48 // pixels from the bottom that still count as "at the bottom"

  connect() {
    this.following = true
    this.scroll()

    this.track = () => { this.following = this.atBottom() }
    this.element.addEventListener("scroll", this.track, { passive: true })

    this.follow = () => { if (this.following) this.scroll() }
    this.mutations = new MutationObserver(this.follow)
    this.mutations.observe(this.element, { childList: true, subtree: true, characterData: true })
    // Late layout changes too: web fonts, an opened step list, the composer growing.
    this.resizes = new ResizeObserver(this.follow)
    this.resizes.observe(this.element)
    for (const child of this.element.children) this.resizes.observe(child)
  }

  disconnect() {
    this.element.removeEventListener("scroll", this.track)
    this.mutations.disconnect()
    this.resizes.disconnect()
  }

  scroll() {
    this.element.scrollTop = this.element.scrollHeight
  }

  atBottom() {
    return this.element.scrollHeight - this.element.scrollTop - this.element.clientHeight <= this.constructor.SLACK
  }
}
