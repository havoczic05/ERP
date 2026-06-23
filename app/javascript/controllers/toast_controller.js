import { Controller } from "@hotwired/stimulus"

// Auto-dismissing toast. Renders visible immediately, then slides out and
// removes itself after `timeout` ms. The × button dismisses on demand.
export default class extends Controller {
  static values = { timeout: { type: Number, default: 4000 } }

  connect() {
    if (this.timeoutValue > 0) {
      this.timer = setTimeout(() => this.dismiss(), this.timeoutValue)
    }
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  dismiss() {
    this.element.classList.add("toast--leaving")
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
    // Fallback in case no transition runs.
    setTimeout(() => this.element.remove(), 400)
  }
}
