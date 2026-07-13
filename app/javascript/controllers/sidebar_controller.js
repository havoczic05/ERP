import { Controller } from "@hotwired/stimulus"

const KEY = "erp:sidebar:collapsed"

export default class extends Controller {
  connect() {
    this.collapsed = localStorage.getItem(KEY) === "true"
    this.#sync()
  }

  toggle() {
    this.collapsed = !this.collapsed
    localStorage.setItem(KEY, String(this.collapsed))
    this.#sync()
  }

  #sync() {
    this.element.classList.toggle("is-sidebar-collapsed", this.collapsed)
  }
}
