import { Controller } from "@hotwired/stimulus"

// Add/remove rows for a nested-attributes fieldset (cocoon-style).
//
// Markup contract:
//   data-controller="nested-form"
//   a container with data-nested-form-target="rows" holding the persisted rows
//   a <template data-nested-form-target="template"> with one blank row whose
//     nested-attributes index is the literal NEW_RECORD placeholder
//   each row has data-nested-form-target="row", an optional [name*='[id]'] hidden
//     field (present only for persisted rows) and a hidden [name*='_destroy'] field
//   "add"    button -> data-action="nested-form#add"
//   "remove" button -> data-action="nested-form#remove"
export default class extends Controller {
  static targets = ["rows", "template"]

  add() {
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, this.uniqueIndex())
    this.rowsTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-nested-form-target='row']")
    if (!row) return

    const persisted = row.querySelector("input[name*='[id]']")
    if (persisted) {
      // Persisted row: flag it for destruction and hide it so the server removes it.
      const destroyField = row.querySelector("input[name*='_destroy']")
      if (destroyField) destroyField.value = "1"
      row.style.display = "none"
    } else {
      // Unsaved row: just drop it from the DOM.
      row.remove()
    }
  }

  // A monotonically-increasing index so each added row gets unique param names.
  uniqueIndex() {
    this.counter = (this.counter || 0) + 1
    return `new_${this.counter}`
  }
}
