import { Controller } from "@hotwired/stimulus"

// Words and photos in the Design tab: what the owner picks in the preview (the point button,
// then a word or a photo) is found among the fields, scrolled to and focused.
export default class extends Controller {
  static targets = [ "text", "photo", "missing" ]

  find({ detail: picked }) {
    const field = this.photoFor(picked) || this.textFor(picked)
    this.missingTarget.hidden = Boolean(field)
    if (!field) return this.missingTarget.scrollIntoView({ block: "nearest" })

    field.scrollIntoView({ block: "center" })
    field.focus({ preventScroll: true })
    field.closest(".design-field, .design-photo")?.classList.add("design-found")
    setTimeout(() => field.closest(".design-found")?.classList.remove("design-found"), 1600)
  }

  // Exactly the words first, then words that hold the field's or sit in it (a heading's span).
  textFor(picked) {
    const words = this.plain(picked.text)
    if (!words) return null
    const fields = this.textTargets.map((input) => [ input, this.plain(input.value) ]).filter(([ , value ]) => value)
    return (fields.find(([ , value ]) => value === words) ||
            fields.find(([ , value ]) => value.length > 8 && words.includes(value)) ||
            fields.find(([ , value ]) => words.length > 8 && value.includes(words)))?.[0]
  }

  photoFor(picked) {
    const html = picked.html || ""
    const row = this.photoTargets.find((element) => {
      const address = (element.dataset.address || "").split("?")[0]
      return address && html.includes(address)
    })
    return row?.querySelector("input[type=file]")
  }

  plain(text) {
    return (text || "").replace(/\s+/g, " ").trim().toLowerCase()
  }
}
