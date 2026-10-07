import { Controller } from "@hotwired/stimulus"

// Picks answers (one per question, or several when the question allows it) and
// sends them as one chat message. Sending opens once the agent's turn has ended:
// the page refresh that follows updates the accepts value, which re-checks it.
export default class extends Controller {
  static targets = [ "question", "body", "send" ]
  static values = { accepts: Boolean }

  connect() {
    this.update()
  }

  acceptsValueChanged() {
    this.update()
  }

  choose(event) {
    const button = event.currentTarget
    const group = button.closest("fieldset")

    if (group.dataset.multiple === "true") {
      button.setAttribute("aria-pressed", button.getAttribute("aria-pressed") !== "true")
    } else {
      group.querySelectorAll("[aria-pressed]").forEach(other => other.setAttribute("aria-pressed", other === button))
    }
    this.update()
  }

  submit(event) {
    if (!this.acceptsValue || !this.complete) event.preventDefault()
  }

  update() {
    if (!this.hasBodyTarget) return
    const answers = this.questionTargets.map(group => [
      group.dataset.question,
      [ ...group.querySelectorAll("[aria-pressed=true]") ].map(button => button.textContent.trim()).join(", ")
    ])

    this.complete = answers.every(([ , answer ]) => answer)
    this.bodyTarget.value = answers.map(([ question, answer ]) => `${question} ${answer}`.trim()).join("\n")
    if (this.hasSendTarget) this.sendTarget.disabled = !this.acceptsValue || !this.complete
  }
}
