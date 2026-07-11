import { Controller } from "@hotwired/stimulus"

// Bridge that auto-selects a just-created client into the sale form's client
// combobox, in place (without reloading the page, so half-entered line items and
// installments are preserved).
//
// Rendered by clients#create when a client is created from the sale context
// (turbo_stream appends this element into #sale-client-receiver). On connect it
// fills the client combobox's hidden id + display input and dispatches the same
// `combobox:select` event a manual pick would, so the existing
// sale-form#clientSelected wiring reveals the selected-client strip. Then it
// removes itself.
export default class extends Controller {
  static values = { id: String, label: String, document: String, editPath: String }

  connect() {
    const combobox = document.querySelector(".client-search")
    if (combobox) {
      const hidden = combobox.querySelector("[data-combobox-target='hidden']")
      const input = combobox.querySelector("[data-combobox-target='input']")
      if (hidden) hidden.value = this.idValue
      if (input) input.value = this.labelValue

      combobox.dispatchEvent(new CustomEvent("combobox:select", {
        bubbles: true,
        detail: {
          id: this.idValue,
          label: this.labelValue,
          document: this.documentValue,
          editPath: this.editPathValue
        }
      }))
    }

    this.element.remove()
  }
}
