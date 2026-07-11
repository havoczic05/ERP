import { Controller } from "@hotwired/stimulus"

// Mobile hamburger drawer for the app sidebar.
//
// The sidebar and all its nav links stay in the DOM at all times — the drawer is
// only hidden off-canvas via CSS, and this controller toggles the open/close
// state. So server-rendered nav links remain present without JS (rack_test specs
// still find them), and this is pure progressive enhancement.
//
// Closes on: the × / toggle button, Esc, a click on the backdrop, and any Turbo
// navigation (so the drawer never lingers across page loads).
export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.onKeydown = (event) => { if (event.key === "Escape") this.close() }
    this.onNavigate = () => this.close()
    document.addEventListener("turbo:before-render", this.onNavigate)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:before-render", this.onNavigate)
  }

  toggle() {
    if (this.element.classList.contains("is-nav-open")) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.element.classList.add("is-nav-open")
    this.#setExpanded(true)
    document.addEventListener("keydown", this.onKeydown)
  }

  close() {
    this.element.classList.remove("is-nav-open")
    this.#setExpanded(false)
    document.removeEventListener("keydown", this.onKeydown)
  }

  #setExpanded(value) {
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", String(value))
  }
}
