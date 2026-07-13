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
    this.positionMenu()
    setTimeout(() => {
      document.addEventListener("click", this.boundClose)
      document.addEventListener("keydown", this.boundKeydown)
      document.addEventListener("scroll", this.boundClose, true)
      window.addEventListener("resize", this.boundClose)
    }, 0)
    this.#toggleAria(true)
  }

  close(event) {
    if (event && event.type !== "scroll" && event.type !== "resize" && this.element.contains(event.target)) return
    this.isOpen = false
    this.menuTarget.hidden = true
    this.menuTarget.style.position = ""
    this.menuTarget.style.top = ""
    this.menuTarget.style.right = ""
    document.removeEventListener("click", this.boundClose)
    document.removeEventListener("keydown", this.boundKeydown)
    document.removeEventListener("scroll", this.boundClose, true)
    window.removeEventListener("resize", this.boundClose)
    this.#toggleAria(false)
  }

  positionMenu() {
    const btnRect = this.element.getBoundingClientRect()
    this.menuTarget.style.position = "fixed"
    
    let top = btnRect.bottom + 4
    const menuRect = this.menuTarget.getBoundingClientRect()
    
    if (top + menuRect.height > window.innerHeight) {
      top = Math.max(4, btnRect.top - menuRect.height - 4)
    }
    
    const viewportWidth = document.documentElement.clientWidth
    this.menuTarget.style.top = `${top}px`
    this.menuTarget.style.right = `${viewportWidth - btnRect.right}px`
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
    document.removeEventListener("scroll", this.boundClose, true)
    window.removeEventListener("resize", this.boundClose)
  }

  #toggleAria(expanded) {
    const toggle = this.element.querySelector(".dropdown-toggle")
    if (toggle) toggle.setAttribute("aria-expanded", String(expanded))
  }
}
