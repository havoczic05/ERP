// Stimulus controller for the sales new/edit form.
//
// Responsibilities:
//  1. Add / remove line-item rows dynamically (clones the first row as template).
//  2. Recompute each row's line_total (qty * unit_price) on input and update
//     the grand total display.
//  3. React to the reusable combobox (combobox_controller.js) `select` event:
//     - client picker -> show the selected client's document + an edit link.
//     - product picker -> autofill the row's unit price and recompute totals.
//
// The search/dropdown behavior itself lives in the generic combobox controller;
// this controller only reacts to its `combobox:select` event.

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "lineItemsBody",
    "lineTotal",
    "grandTotal",
    "quantity",
    "unitPrice",
    "numInstallments",
    "intervalDays",
    "clientMeta",
    "clientDoc",
    "clientEdit",
  ]

  // -------------------------------------------------------------------------
  // Add a new line-item row by cloning the first row
  // -------------------------------------------------------------------------
  addLine() {
    const body = this.lineItemsBodyTarget
    const firstRow = body.querySelector("tr.line-item")
    if (!firstRow) return

    const newRow = firstRow.cloneNode(true)

    // Reset inputs (quantity back to 1, everything else cleared, incl. the
    // hidden product_id carried by the product combobox).
    newRow.querySelectorAll("input").forEach((input) => {
      input.value = input.type === "number" && input.name.includes("quantity") ? "1" : ""
    })

    // Reset the cloned combobox: close it and drop any stale results.
    const results = newRow.querySelector(".combobox-results")
    if (results) results.innerHTML = ""
    newRow.querySelector(".combobox")?.classList.remove("is-open")

    const lineTotalCell = newRow.querySelector("[data-sale-form-target='lineTotal']")
    if (lineTotalCell) lineTotalCell.textContent = "USD 0.00"

    body.appendChild(newRow)
  }

  // -------------------------------------------------------------------------
  // Remove the closest line-item row (prevent removing the last one)
  // -------------------------------------------------------------------------
  removeLine(event) {
    const rows = this.lineItemsBodyTarget.querySelectorAll("tr.line-item")
    if (rows.length <= 1) return // always keep at least one row

    event.currentTarget.closest("tr.line-item")?.remove()
    this.updateGrandTotal()
  }

  // -------------------------------------------------------------------------
  // Recompute a single row's line_total and refresh the grand total
  // -------------------------------------------------------------------------
  recompute(event) {
    this.recomputeRow(event.currentTarget.closest("tr.line-item"))
  }

  recomputeRow(row) {
    if (!row) return
    const qty = parseFloat(row.querySelector("[data-sale-form-target='quantity']")?.value) || 0
    const price = parseFloat(row.querySelector("[data-sale-form-target='unitPrice']")?.value) || 0

    const lineTotalCell = row.querySelector("[data-sale-form-target='lineTotal']")
    if (lineTotalCell) lineTotalCell.textContent = `USD ${(qty * price).toFixed(2)}`

    this.updateGrandTotal()
  }

  // -------------------------------------------------------------------------
  // Sum all row line totals and display in grandTotal target
  // -------------------------------------------------------------------------
  updateGrandTotal() {
    let total = 0
    this.lineItemsBodyTarget.querySelectorAll("tr.line-item").forEach((row) => {
      const qty = parseFloat(row.querySelector("[data-sale-form-target='quantity']")?.value) || 0
      const price = parseFloat(row.querySelector("[data-sale-form-target='unitPrice']")?.value) || 0
      total += qty * price
    })

    if (this.hasGrandTotalTarget) this.grandTotalTarget.textContent = total.toFixed(2)
  }

  // -------------------------------------------------------------------------
  // combobox:select reactions
  // -------------------------------------------------------------------------

  // Client picker: reveal the selected client's document + edit link.
  clientSelected(event) {
    const { document: doc, editPath } = event.detail
    if (this.hasClientDocTarget) this.clientDocTarget.textContent = doc || ""
    if (this.hasClientEditTarget && editPath) this.clientEditTarget.href = editPath
    if (this.hasClientMetaTarget) this.clientMetaTarget.hidden = false
  }

  // Product picker: autofill the row's unit price, then recompute.
  productSelected(event) {
    const row = event.target.closest("tr.line-item")
    if (!row) return

    const priceInput = row.querySelector("[data-sale-form-target='unitPrice']")
    if (priceInput && event.detail.price) {
      priceInput.value = parseFloat(event.detail.price).toFixed(2)
    }
    this.recomputeRow(row)
  }
}
