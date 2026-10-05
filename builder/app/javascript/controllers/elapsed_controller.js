import { Controller } from "@hotwired/stimulus"

// A running clock for the current agent turn, so it's clear work is happening.
export default class extends Controller {
  static targets = [ "clock" ]
  static values = { since: Number }

  connect() {
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    const seconds = Math.max(0, Math.floor(Date.now() / 1000 - this.sinceValue))
    const minutes = Math.floor(seconds / 60)
    this.clockTarget.textContent = minutes ? `${minutes}m ${String(seconds % 60).padStart(2, "0")}s` : `${seconds}s`
  }
}
