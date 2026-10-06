import { Controller } from "@hotwired/stimulus"

const CHOICES = [ "system", "light", "dark" ]
const NAMES = { system: "Same as the system", light: "Light", dark: "Dark" }

// Switches the studio between following the system, light and dark. The choice is kept
// in a cookie so the page is drawn in it from the start.
export default class extends Controller {
  connect() {
    this.show(this.element.dataset.themeChoice)
  }

  cycle() {
    const choice = CHOICES[(CHOICES.indexOf(this.element.dataset.themeChoice) + 1) % CHOICES.length]

    if (choice === "system") {
      delete document.documentElement.dataset.theme
      document.cookie = "theme=; path=/; max-age=0; samesite=lax"
    } else {
      document.documentElement.dataset.theme = choice
      document.cookie = `theme=${choice}; path=/; max-age=31536000; samesite=lax`
    }
    this.show(choice)
  }

  show(choice) {
    const next = CHOICES[(CHOICES.indexOf(choice) + 1) % CHOICES.length]
    this.element.dataset.themeChoice = choice
    this.element.title = `Theme: ${NAMES[choice]}. Click for ${NAMES[next].toLowerCase()}.`
  }
}
