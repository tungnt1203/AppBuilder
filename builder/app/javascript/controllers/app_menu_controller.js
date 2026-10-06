import { Controller } from "@hotwired/stimulus"

// The menu on an app's card opens its rename and delete dialogs. Live page
// refreshes morph the card, which would close a dialog the owner is using.
export default class extends Controller {
  static targets = [ "dialog" ]

  connect() {
    this.keep = (event) => {
      if (event.target.tagName === "DIALOG" && event.detail.attributeName === "open") event.preventDefault()
    }
    this.element.addEventListener("turbo:before-morph-attribute", this.keep)
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-morph-attribute", this.keep)
  }

  open({ params: { name } }) {
    this.element.querySelector("details").open = false
    this.dialogTargets.find((dialog) => dialog.dataset.name === name).showModal()
  }

  close() {
    this.dialogTargets.forEach((dialog) => dialog.open && dialog.close())
  }

  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) event.currentTarget.close()
  }
}
