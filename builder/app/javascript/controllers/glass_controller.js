import { Controller } from "@hotwired/stimulus"

// Moves each glass surface's specular highlight toward the pointer, the way
// light catches real glass as you move around it. Off for reduced motion.
export default class extends Controller {
  connect() {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.move = (event) => {
      this.pointer = event
      this.frame ||= requestAnimationFrame(() => this.update())
    }
    window.addEventListener("pointermove", this.move, { passive: true })
  }

  disconnect() {
    window.removeEventListener("pointermove", this.move)
    cancelAnimationFrame(this.frame)
  }

  update() {
    this.frame = null
    const { clientX, clientY } = this.pointer

    for (const glass of this.element.querySelectorAll(".glass")) {
      const box = glass.getBoundingClientRect()
      const x = ((clientX - box.left) / box.width) * 100
      const y = ((clientY - box.top) / box.height) * 100
      // Stay near the top edge, leaning toward the pointer, like an overhead light.
      glass.style.setProperty("--mx", `${Math.max(-20, Math.min(120, x))}%`)
      glass.style.setProperty("--my", `${Math.max(-40, Math.min(30, y / 3 - 20))}%`)
    }
  }
}
