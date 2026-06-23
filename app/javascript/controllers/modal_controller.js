import { Controller } from "@hotwired/stimulus"

// Upgrades a server-rendered <dialog open> into a true modal dialog.
//
// Progressive enhancement: without JS the <dialog open> is just a visible panel
// (so the form still works as a plain page). With JS we promote it to a real
// modal via showModal() — native focus trap, Esc-to-close and backdrop.
//
// Closing just closes the dialog (it stays in the turbo-frame, hidden). Opening
// another modal re-navigates <turbo-frame id="modal">, replacing this dialog.
export default class extends Controller {
  connect() {
    const dialog = this.element
    if (typeof dialog.showModal !== "function") return // very old browser: leave open

    // Drop the server-rendered `open` attribute WITHOUT firing "close", then
    // promote to a true modal.
    dialog.removeAttribute("open")
    if (!dialog.open) dialog.showModal()

    this.onClick = (event) => { if (event.target === dialog) dialog.close() } // backdrop
    dialog.addEventListener("click", this.onClick)
  }

  disconnect() {
    this.element.removeEventListener("click", this.onClick)
  }

  // × button.
  dismiss(event) {
    if (event) event.preventDefault()
    if (this.element.open) this.element.close()
  }
}
