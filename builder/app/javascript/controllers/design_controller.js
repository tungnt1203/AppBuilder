import { Controller } from "@hotwired/stimulus"

// The Design tab's form: every change is tried on in the preview at once, by sending the
// theme's CSS variables to the template's preview probe, the same ones ProjectDesign#variables
// writes on Save. Discard puts the preview and the form back as saved.
export default class extends Controller {
  static targets = [ "color", "hex", "warning" ]
  static values = { settings: Object }

  disconnect() {
    this.send(null)
  }

  preview() {
    const choice = this.choice()
    this.colorTargets.forEach((input, index) => { this.hexTargets[index].textContent = input.value })
    this.send(this.variables(choice))
    this.warn(choice)
  }

  discard() {
    this.element.reset()
    this.colorTargets.forEach((input, index) => { this.hexTargets[index].textContent = input.value })
    this.warningTarget.hidden = true
    this.send(null)
  }

  choice() {
    const value = (name) => this.element.elements[`design[${name}]`]?.value
    return { brand: value("brand"), background: value("background"), text: value("text"), accent: value("accent"),
             heading: value("heading_font"), body: value("text_font"), corners: value("corners"), width: value("width") }
  }

  variables(choice) {
    const settings = this.settingsValue
    const dark = !this.light(choice.background)
    const variables = {
      "--color-canvas": choice.background, "--color-ink": choice.text, "--color-accent": choice.accent,
      "--color-brand-600": choice.brand, "--color-on-brand": this.onBrand(choice.brand),
      "--font-display": this.family(settings.display, choice.heading), "--font-sans": this.family(settings.sans, choice.body),
      "--radius-lg": settings.corners[choice.corners][0], "--radius-xl": settings.corners[choice.corners][1],
      "--page-width": settings.widths[choice.width]
    }
    if (settings.surfaceFollows) variables["--color-surface"] = choice.background
    for (const [ step, share ] of Object.entries(settings.scale)) {
      const toward = (Number(step) < 600) !== dark ? "white" : "black"
      variables[`--color-brand-${step}`] = `color-mix(in oklch, ${choice.brand} ${share}%, ${toward})`
    }
    return variables
  }

  family(stack, name) {
    return stack ? stack.replace(/"[^"]+"/, `"${name}"`) : `"${name}", ui-sans-serif, system-ui, sans-serif`
  }

  warn(choice) {
    const problems = []
    if (this.contrast(choice.brand, this.onBrand(choice.brand)) < 4.5) problems.push("Words on buttons will be hard to read in this color.")
    if (this.contrast(choice.text, choice.background) < 4.5) problems.push("The text is hard to read on this background.")
    this.warningTarget.textContent = problems.join(" ")
    this.warningTarget.hidden = problems.length === 0
  }

  send(variables) {
    const frame = document.querySelector("[data-preview-target='frame']")
    frame?.contentWindow?.postMessage({ type: "preview:design", variables }, "*")
  }

  luminance(hex) {
    const channels = (hex || "").replace("#", "").match(/../g)?.map((pair) => parseInt(pair, 16) / 255) || [ 1, 1, 1 ]
    const [ red, green, blue ] = channels.map((c) => c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue
  }

  // Dark or white words on the brand color, whichever reads better (ProjectDesign#on_brand).
  onBrand(hex) {
    return this.contrast(hex, "#1a1a1a") > this.contrast(hex, "#ffffff") ? "#1a1a1a" : "#ffffff"
  }

  light(hex) {
    return this.luminance(hex) > 0.4
  }

  contrast(first, second) {
    const [ high, low ] = [ this.luminance(first), this.luminance(second) ].sort((a, b) => b - a)
    return (high + 0.05) / (low + 0.05)
  }
}
