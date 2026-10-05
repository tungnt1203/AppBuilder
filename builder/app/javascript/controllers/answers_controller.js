import { Controller } from "@hotwired/stimulus"

// Picks one answer per question and sends them as a single chat message.
export default class extends Controller {
  static targets = [ "question", "body", "send" ]

  connect() {
    this.blocked = this.hasSendTarget && this.sendTarget.disabled // the agent is busy
    this.update()
  }

  choose(event) {
    const group = event.currentTarget.closest("fieldset")
    group.querySelectorAll("[aria-pressed]").forEach(button => button.setAttribute("aria-pressed", button === event.currentTarget))
    this.update()
  }

  submit(event) {
    if (!this.complete) event.preventDefault()
  }

  update() {
    const answers = this.questionTargets.map(group => [ group.dataset.question, group.querySelector("[aria-pressed=true]")?.textContent.trim() ])
    this.complete = answers.every(([ , answer ]) => answer)
    this.bodyTarget.value = answers.map(([ question, answer ]) => `${question} ${answer ?? ""}`.trim()).join("\n")
    if (this.hasSendTarget) this.sendTarget.disabled = this.blocked || !this.complete
  }
}
