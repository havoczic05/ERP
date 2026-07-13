import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message", "actionBtn"]

  connect() {
    this.pendingForm = null
    this.boundClickHandler = this.handleClick.bind(this)
    document.addEventListener("click", this.boundClickHandler, true)
    this.element.addEventListener("close", () => this.cancel())
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickHandler, true)
  }

  handleClick(event) {
    if (this.element.open) return

    const button = event.target.closest("button,[role='button']")
    if (!button) return

    const form = button.closest("form")
    if (!form) return

    const message = button.getAttribute("data-turbo-confirm")
      || form.getAttribute("data-turbo-confirm")
    if (!message) return

    event.preventDefault()
    event.stopImmediatePropagation()

    this.pendingForm = form
    this.messageTarget.textContent = message
    this.actionBtnTarget.textContent = (button.textContent || "").trim() || "Confirmar"
    this.element.showModal()
  }

  proceed() {
    this.element.close()
    if (this.pendingForm) {
      const form = this.pendingForm
      form.removeAttribute("data-turbo-confirm")
      form.requestSubmit()
      this.pendingForm = null
    }
  }

  cancel() {
    this.element.close()
    this.pendingForm = null
  }
}
