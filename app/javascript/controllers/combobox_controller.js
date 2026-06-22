// Generic searchable combobox (reusable across forms).
//
// Markup (rendered by the `combobox` view helper):
//   <div data-controller="combobox" data-combobox-url-value="/things/search"
//        data-action="combobox:select->other#react">
//     <input data-combobox-target="input" data-action="input->combobox#search">
//     <input type="hidden" data-combobox-target="hidden" name="...">
//     <div class="combobox-results" data-combobox-target="results"></div>
//   </div>
//
// Behavior: typing fetches `url?q=...` and injects the returned options HTML
// (a list of `button.picker-option` with data-id / data-label / extras). Picking
// an option fills the hidden id + the input display, closes the dropdown, and
// dispatches `combobox:select` with the full option dataset as `event.detail`, so
// the embedding controller can react (e.g. autofill a price, show a document).
//
// Uses fetch + innerHTML (not a Turbo Frame) so multiple instances — including
// per-row pickers cloned at runtime — never collide on a frame id.

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hidden", "results"]
  static values = { url: String }

  connect() {
    this._onDocClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this._onKeydown = (event) => {
      if (event.key === "Escape") this.close()
    }
    document.addEventListener("click", this._onDocClick)
    document.addEventListener("keydown", this._onKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this._onDocClick)
    document.removeEventListener("keydown", this._onKeydown)
  }

  async search() {
    // Editing the text invalidates any committed selection: drop the hidden id
    // and let hosts react (e.g. disable the client's edit link).
    if (this.hiddenTarget.value) {
      this.hiddenTarget.value = ""
      this.dispatch("clear")
    }

    const q = this.inputTarget.value.trim()
    if (q.length === 0) {
      this.clear()
      return
    }

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", q)

    try {
      const response = await fetch(url, { headers: { Accept: "text/html" } })
      this.resultsTarget.innerHTML = await response.text()
      this.open()
    } catch {
      this.clear()
    }
  }

  select(event) {
    const option = event.currentTarget
    this.hiddenTarget.value = option.dataset.id || ""
    this.inputTarget.value = option.dataset.label || ""
    this.close()
    this.dispatch("select", { detail: { ...option.dataset } })
  }

  open() {
    this.element.classList.add("is-open")
  }

  close() {
    this.element.classList.remove("is-open")
  }

  clear() {
    this.resultsTarget.innerHTML = ""
    this.close()
  }
}
