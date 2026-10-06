import { Controller } from "@hotwired/stimulus"

// Picks answers (one per question, or several when the question allows it) and
// sends them as one chat message.
export default class extends Controller {
  static targets = [ "question", "body", "send" ]

  connect() {
    this.blocked = this.hasSendTarget && this.sendTarget.disabled // nothing is waiting for answers
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
    if (!this.complete) event.preventDefault()
  }

  update() {
    const answers = this.questionTargets.map(group => [
      group.dataset.question,
      [ ...group.querySelectorAll("[aria-pressed=true]") ].map(button => button.textContent.trim()).join(", ")
    ])

    this.complete = answers.every(([ , answer ]) => answer)
    this.bodyTarget.value = answers.map(([ question, answer ]) => `${question} ${answer}`.trim()).join("\n")
    if (this.hasSendTarget) this.sendTarget.disabled = this.blocked || !this.complete
  }
}
