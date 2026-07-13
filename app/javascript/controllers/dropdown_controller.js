import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.isOpen = false
    this.boundClose = this.close.bind(this)
    this.boundKeydown = this.onKeydown.bind(this)
    this.boundTurbo = () => this.close()
    document.addEventListener("turbo:before-render", this.boundTurbo)
  }

  disconnect() {
    this.cleanup()
    document.removeEventListener("turbo:before-render", this.boundTurbo)
  }

  toggle() {
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.isOpen = true
    this.menuTarget.hidden = false
    setTimeout(() => {
      document.addEventListener("click", this.boundClose)
      document.addEventListener("keydown", this.boundKeydown)
    }, 0)
    this.#toggleAria(true)
  }

  close(event) {
    if (event && this.element.contains(event.target)) return
    this.isOpen = false
    this.menuTarget.hidden = true
    document.removeEventListener("click", this.boundClose)
    document.removeEventListener("keydown", this.boundKeydown)
    this.#toggleAria(false)
  }

  onKeydown(event) {
    if (event.key === "Escape") {
      this.close()
      const toggle = this.element.querySelector(".dropdown-toggle")
      if (toggle) toggle.focus()
    }
  }

  cleanup() {
    document.removeEventListener("click", this.boundClose)
    document.removeEventListener("keydown", this.boundKeydown)
  }

  #toggleAria(expanded) {
    const toggle = this.element.querySelector(".dropdown-toggle")
    if (toggle) toggle.setAttribute("aria-expanded", String(expanded))
  }
}
