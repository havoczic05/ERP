import { Controller } from "@hotwired/stimulus"

// Opens a filter dialog that is loaded into <turbo-frame id="modal">.
//
// The persistent frame lives in shared/_modal_frame. A link with
// data-action="click->filter-dialog#load" sets the frame src to the filters
// route; once Turbo finishes loading, this controller finds the dialog inside
// the frame and promotes it to a real modal via showModal().
export default class extends Controller {
  static targets = ["dialog"]

  load(event) {
    event.preventDefault()
    const frame = document.getElementById("modal")
    if (frame) frame.src = event.currentTarget.href
  }

  open() {
    if (!this.hasDialogTarget) return

    const dialog = this.dialogTarget
    if (typeof dialog.showModal !== "function") return

    // The server may render <dialog open> as a no-JS fallback. Remove that
    // attribute before promoting to a true modal; showModal() throws on a
    // dialog that already has `open`.
    if (dialog.open) dialog.removeAttribute("open")
    dialog.showModal()
  }

  close() {
    if (this.hasDialogTarget && this.dialogTarget.open) {
      this.dialogTarget.close()
    }

    const frame = this.element.querySelector("turbo-frame#modal")
    if (frame) {
      frame.innerHTML = ""
      frame.removeAttribute("src")
    }
  }
}
