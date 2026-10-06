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
//
// The app reports JavaScript errors and error pages (config/initializers/preview_probe.rb
// in the template) by postMessage; they show over the app with a button that asks
// the agent to fix them.
export default class extends Controller {
  static targets = [ "stage", "frame", "device", "bezel", "tab", "code", "codeFiles",
                     "errorBox", "errorTitle", "errorPage", "errorMessage", "errorRequest", "errorFix" ]
  static values = { version: Number, state: String, accepts: Boolean }
  static MAX_ERRORS = 5
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
    this.errors = new Map()
    this.onMessage = (event) => this.previewError(event)
    window.addEventListener("message", this.onMessage)
    this.waitForLoad()
  }

  disconnect() {
    document.removeEventListener("turbo:before-morph-element", this.skipMorph)
    document.removeEventListener("turbo:morph", this.restoreSize)
    document.removeEventListener("turbo:before-frame-render", this.keepScroll)
    window.removeEventListener("message", this.onMessage)
    clearTimeout(this.loadTimeout)
  }

  versionValueChanged(_version, previous) {
    if (previous === undefined) return
    this.dismissErrors()
    this.reload()
    if (this.hasCodeTarget && this.codeTarget.src) this.codeTarget.reload()
  }

  stateValueChanged(state, previous) {
    if (previous !== undefined && state !== previous) this.unpeek()
    if (this.hasErrorBoxTarget) this.showErrors()
  }

  acceptsValueChanged() {
    if (this.hasErrorBoxTarget) this.showErrors()
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

  // Only from the app in the iframe, and only while it's meant to work: not while
  // the agent is halfway through a change.
  previewError(event) {
    const data = event.data
    if (!this.hasFrameTarget || event.source !== this.frameTarget.contentWindow || data?.type !== "preview:error") return
    if (![ "live", "broken" ].includes(this.stateValue)) return

    const clip = (value, length) => typeof value === "string" ? value.slice(0, length) : ""
    const error = { kind: data.kind === "page" ? "page" : "javascript", status: Number(data.status) || null, page: clip(data.page, 300),
                    message: clip(data.message, 1500), source: clip(data.source, 300), stack: clip(data.stack, 1500) }
    const key = [ error.kind, error.page, error.message ].join("|")
    this.errors.delete(key)
    this.errors.set(key, error)
    if (this.errors.size > this.constructor.MAX_ERRORS) this.errors.delete(this.errors.keys().next().value)
    this.showErrors()
  }

  showErrors() {
    if (!this.errors) return // value callbacks run before connect()
    const errors = [ ...this.errors.values() ]
    const latest = errors.at(-1)
    this.errorBoxTarget.hidden = !latest || ![ "live", "broken" ].includes(this.stateValue)
    if (!latest) return

    const more = errors.length > 1 ? ` (+${errors.length - 1} more)` : ""
    this.errorTitleTarget.textContent = (latest.kind === "page" ? `Error page ${latest.status || ""}`.trim() : "JavaScript error") + more
    this.errorPageTarget.textContent = latest.page ? `on ${latest.page}` : ""
    this.errorMessageTarget.textContent = latest.message.split("\n").at(-1) || latest.message
    this.errorMessageTarget.title = latest.message
    this.errorRequestTarget.value = this.fixRequest(errors)
    this.errorFixTarget.disabled = !this.acceptsValue
    this.errorFixTarget.title = this.acceptsValue ? "Ask the agent to fix it" : "Wait until the current step finishes"
  }

  fixRequest(errors) {
    const described = errors.map((error) => [
      error.kind === "page" ? `Error page (${error.status || "error"}) on ${error.page}:` : `JavaScript error on ${error.page}:`,
      error.message,
      error.source && `At ${error.source}`,
      error.stack && `Stack:\n${error.stack.split("\n").slice(0, 8).join("\n")}`
    ].filter(Boolean).join("\n"))
    return [ `I hit ${errors.length > 1 ? "these errors" : "this error"} while trying the app in the preview:`, ...described,
             "Please find the cause and fix it." ].join("\n\n")
  }

  errorSent() {
    setTimeout(() => this.dismissErrors()) // after the form has read the request
  }

  dismissErrors() {
    this.errors?.clear()
    if (this.hasErrorBoxTarget) this.errorBoxTarget.hidden = true
  }

  // Cross-origin, so the only signal is the load event; a page that never loads
  // shouldn't hide the app forever.
  waitForLoad() {
    this.stageTarget.setAttribute("data-loading", "")
    clearTimeout(this.loadTimeout)
    this.loadTimeout = setTimeout(() => this.loaded(), this.constructor.LOAD_TIMEOUT)
  }
}
