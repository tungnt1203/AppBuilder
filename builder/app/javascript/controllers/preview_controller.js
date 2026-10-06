import { Controller } from "@hotwired/stimulus"

// The preview iframe and the screens over it.
//
// Page refreshes morph the studio many times per turn. Turbo takes permanent
// elements out and puts them back, which reloads an iframe, so instead the stage
// (iframe and its loading veil) is left out of morphing altogether. The server
// says what to show through the state and version values, which do morph.
//
// - version changes after the preview restarts: reload behind the veil
// - state "building", "broken": the owner can peek at the app under the screen
//
// The screen size (desktop, tablet, phone) lives on the stage too, and the
// owner's last choice is remembered in this browser. The Code tab covers the
// stage; its frame is kept out of morphing the same way, and reloads with the app.
export default class extends Controller {
  static targets = [ "stage", "frame", "device", "bezel", "tab", "code", "codeFiles" ]
  static values = { version: Number, state: String }
  static LOAD_TIMEOUT = 15000

  connect() {
    this.skipMorph = (event) => {
      if (event.target === this.stageTarget || (this.hasCodeTarget && event.target === this.codeTarget)) event.preventDefault()
    }
    document.addEventListener("turbo:before-morph-element", this.skipMorph)
    this.restoreSize = () => { this.showSize(this.size); this.showTab({ params: { tab: this.tab } }) }
    document.addEventListener("turbo:morph", this.restoreSize)
    this.keepScroll = (event) => this.keepFilesScroll(event)
    document.addEventListener("turbo:before-frame-render", this.keepScroll)
    this.showSize(this.savedSize())
    this.tab = "preview"
    this.waitForLoad()
  }

  disconnect() {
    document.removeEventListener("turbo:before-morph-element", this.skipMorph)
    document.removeEventListener("turbo:morph", this.restoreSize)
    document.removeEventListener("turbo:before-frame-render", this.keepScroll)
    clearTimeout(this.loadTimeout)
  }

  versionValueChanged(_version, previous) {
    if (previous === undefined) return
    this.reload()
    if (this.hasCodeTarget && this.codeTarget.src) this.codeTarget.reload()
  }

  stateValueChanged(state, previous) {
    if (previous !== undefined && state !== previous) this.unpeek()
  }

  reload() {
    if (!this.hasFrameTarget) return
    this.waitForLoad()
    this.frameTarget.src = this.frameTarget.src
  }

  loaded() {
    clearTimeout(this.loadTimeout)
    this.stageTarget.removeAttribute("data-loading")
  }

  peek() {
    this.stageTarget.setAttribute("data-peek", "")
  }

  unpeek() {
    this.stageTarget.removeAttribute("data-peek")
  }

  showTab({ params: { tab } }) {
    this.tab = tab === "code" ? "code" : "preview"
    this.bezelTarget.dataset.tab = this.tab
    if (this.tab === "code" && !this.codeTarget.src) this.codeTarget.src = this.codeTarget.dataset.src
    this.tabTargets.forEach((button) => button.setAttribute("aria-selected", button.dataset.previewTabParam === this.tab))
  }

  // Opening another file re-renders the list beside it; keep the list where it was scrolled to.
  keepFilesScroll(event) {
    if (!this.hasCodeTarget || event.target !== this.codeTarget || !this.hasCodeFilesTarget) return
    const top = this.codeFilesTarget.scrollTop
    const render = event.detail.render
    event.detail.render = async (current, next) => {
      await render(current, next)
      if (this.hasCodeFilesTarget) this.codeFilesTarget.scrollTop = top
    }
  }

  resize({ params: { size } }) {
    this.showSize(size)
    try { localStorage.setItem("preview-size", size) } catch {}
  }

  toggleFullscreen() {
    if (document.fullscreenElement) document.exitFullscreen()
    else this.bezelTarget.requestFullscreen?.().catch(() => {}) // refused, for example outside a click
  }

  showSize(size) {
    this.size = [ "tablet", "phone" ].includes(size) ? size : "desktop"
    if (this.size === "desktop") this.stageTarget.removeAttribute("data-size")
    else this.stageTarget.setAttribute("data-size", this.size)
    this.deviceTargets.forEach((button) => button.setAttribute("aria-pressed", button.dataset.previewSizeParam === this.size))
  }

  savedSize() {
    try { return localStorage.getItem("preview-size") } catch { return null }
  }

  // Cross-origin, so the only signal is the load event; a page that never loads
  // shouldn't hide the app forever.
  waitForLoad() {
    this.stageTarget.setAttribute("data-loading", "")
    clearTimeout(this.loadTimeout)
    this.loadTimeout = setTimeout(() => this.loaded(), this.constructor.LOAD_TIMEOUT)
  }
}
