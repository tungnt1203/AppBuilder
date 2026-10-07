import { Controller } from "@hotwired/stimulus"

const MAX_FILES = 10
const MAX_SIZE = 20 * 1024 * 1024
const TYPES = /^(image\/(png|jpeg|gif|webp|svg\+xml)|application\/pdf|text\/(plain|csv))$/

// Files to send with a message: picked with the paperclip, pasted (a screenshot) or
// dropped on the message box. They're shown above it and can be taken off again.
export default class extends Controller {
  static targets = [ "input", "list", "body" ]

  connect() {
    this.files = []
    this.messages = document.getElementById("messages")
  }

  pick() {
    this.inputTarget.click()
  }

  add() {
    this.keep([ ...this.inputTarget.files ])
  }

  paste(event) {
    const files = [ ...(event.clipboardData?.files || []) ]
    if (files.length === 0) return

    event.preventDefault()
    this.keep(files)
  }

  dragOver(event) {
    if (!event.dataTransfer?.types.includes("Files") || this.inputTarget.disabled) return
    event.preventDefault()
    this.element.classList.add("dropping")
  }

  dragLeave() {
    this.element.classList.remove("dropping")
  }

  drop(event) {
    this.element.classList.remove("dropping")
    if (!event.dataTransfer?.files.length || this.inputTarget.disabled) return

    event.preventDefault()
    this.keep([ ...event.dataTransfer.files ])
  }

  remove(event) {
    this.files.splice(Number(event.currentTarget.dataset.index), 1)
    this.sync()
  }

  keep(files) {
    const known = new Set(this.files.map(file => `${file.name}:${file.size}`))
    const allowed = files.filter(file => TYPES.test(file.type) && file.size <= MAX_SIZE && !known.has(`${file.name}:${file.size}`))
    this.files = [ ...this.files, ...allowed ].slice(0, MAX_FILES)
    this.sync()
    this.bodyTarget.focus()
  }

  // The file field sends exactly the files shown.
  sync() {
    const transfer = new DataTransfer()
    this.files.forEach(file => transfer.items.add(file))
    this.inputTarget.files = transfer.files
    this.bodyTarget.required = this.files.length === 0
    this.render()
  }

  render() {
    this.previews?.forEach(url => URL.revokeObjectURL(url))
    this.previews = []
    this.listTarget.hidden = this.files.length === 0
    this.listTarget.replaceChildren(...this.files.map((file, index) => {
      const item = document.createElement("li")
      if (file.type.startsWith("image/")) {
        const image = document.createElement("img")
        image.src = URL.createObjectURL(file)
        image.alt = file.name
        this.previews.push(image.src)
        item.append(image)
      } else {
        const name = document.createElement("span")
        name.className = "attachment-file"
        name.textContent = file.name
        item.append(name)
      }

      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "attachment-remove"
      remove.dataset.index = index
      remove.dataset.action = "attachments#remove"
      remove.setAttribute("aria-label", `Remove ${file.name}`)
      remove.textContent = "×"
      item.append(remove)
      item.title = file.name
      return item
    }))
    this.makeRoom()
  }

  // The files sit above the message box; the end of the chat stays visible above them.
  makeRoom() {
    if (!this.messages) return

    this.messages.style.paddingBottom = ""
    if (this.listTarget.hidden) return
    const padding = parseFloat(getComputedStyle(this.messages).paddingBottom)
    this.messages.style.paddingBottom = `${padding + this.listTarget.offsetHeight + 8}px`
    this.messages.scrollTop = this.messages.scrollHeight
  }
}
