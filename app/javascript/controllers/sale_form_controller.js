// Stimulus controller for the sales new/edit form.
//
// Responsibilities:
//  1. Add / remove line-item rows dynamically (clones the first row as template).
//  2. Recompute each row's line_total (qty * unit_price) on input and update
//     the grand total display.
//  3. Drive the Turbo Frame client-picker by appending the search query to the
//     frame's src URL when the user types in the search field.
//
// W-3 DEBT: These behaviors are NOT covered by automated system specs because
// no Chrome/Chromium headless driver is available in this WSL2 environment.
// All live-JS coverage is deferred to manual QA or a future CI environment
// with a real browser driver. The authoritative automated coverage for
// totals/stock/installment math lives in service + model + request specs.
//
// Activation: include data-controller="sale-form" on the line-items wrapper
// and data-sale-form-search-url-value on the same element with the search URL.

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
  ]

  static values = {
    searchUrl: String,
  }

  // -------------------------------------------------------------------------
  // Add a new line-item row by cloning the first row
  // -------------------------------------------------------------------------
  addLine() {
    const body = this.lineItemsBodyTarget
    const firstRow = body.querySelector("tr.line-item")
    if (!firstRow) return

    const newRow = firstRow.cloneNode(true)

    // Reset all inputs in the cloned row
    newRow.querySelectorAll("input").forEach((input) => {
      input.value = input.type === "number" && input.name.includes("quantity") ? "1" : ""
    })

    // Reset the line total display
    const lineTotalCell = newRow.querySelector("[data-sale-form-target='lineTotal']")
    if (lineTotalCell) lineTotalCell.textContent = "USD 0.00"

    body.appendChild(newRow)
  }

  // -------------------------------------------------------------------------
  // Remove the closest line-item row (prevent removing the last one)
  // -------------------------------------------------------------------------
  removeLine(event) {
    const body = this.lineItemsBodyTarget
    const rows = body.querySelectorAll("tr.line-item")
    if (rows.length <= 1) return // always keep at least one row

    const row = event.currentTarget.closest("tr.line-item")
    if (row) {
      row.remove()
      this.updateGrandTotal()
    }
  }

  // -------------------------------------------------------------------------
  // Recompute a single row's line_total and refresh the grand total
  // -------------------------------------------------------------------------
  recompute(event) {
    const row = event.currentTarget.closest("tr.line-item")
    if (!row) return

    const qty = parseFloat(row.querySelector("[data-sale-form-target='quantity']")?.value) || 0
    const price = parseFloat(row.querySelector("[data-sale-form-target='unitPrice']")?.value) || 0
    const lineTotal = qty * price

    const lineTotalCell = row.querySelector("[data-sale-form-target='lineTotal']")
    if (lineTotalCell) lineTotalCell.textContent = `USD ${lineTotal.toFixed(2)}`

    this.updateGrandTotal()
  }

  // -------------------------------------------------------------------------
  // Sum all row line totals and display in grandTotal target
  // -------------------------------------------------------------------------
  updateGrandTotal() {
    const rows = this.lineItemsBodyTarget.querySelectorAll("tr.line-item")
    let total = 0

    rows.forEach((row) => {
      const qty = parseFloat(row.querySelector("[data-sale-form-target='quantity']")?.value) || 0
      const price = parseFloat(row.querySelector("[data-sale-form-target='unitPrice']")?.value) || 0
      total += qty * price
    })

    if (this.hasGrandTotalTarget) {
      this.grandTotalTarget.textContent = total.toFixed(2)
    }
  }

  // -------------------------------------------------------------------------
  // Drive the Turbo Frame client picker by updating its src attribute.
  // The Turbo Frame observes src changes and fetches /clients/search?q=...
  // -------------------------------------------------------------------------
  searchClient(event) {
    const q = event.currentTarget.value.trim()
    const frame = document.getElementById("client-picker")
    if (!frame) return

    const url = new URL(this.searchUrlValue, window.location.origin)
    url.searchParams.set("q", q)
    frame.src = url.toString()
  }
}
