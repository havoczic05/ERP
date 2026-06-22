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
    "warehouse",
    "clientDoc",
    "clientEdit",
  ]

  static values = { productSearchUrl: String }

  connect() {
    this.togglePaymentMode()
    this.syncWarehouseGating()
  }

  // -------------------------------------------------------------------------
  // Warehouse gates the product pickers: until an almacén is chosen the product
  // search is disabled; choosing one enables it and scopes the search to that
  // warehouse (combobox url gets ?warehouse_id=...).
  // -------------------------------------------------------------------------
  warehouseChanged() {
    this.syncWarehouseGating()
  }

  syncWarehouseGating() {
    const id = this.hasWarehouseTarget ? this.warehouseTarget.value : ""
    const enabled = id !== ""
    const base = this.productSearchUrlValue

    this.element.querySelectorAll(".combobox.product-search").forEach((cb) => {
      const input = cb.querySelector("[data-combobox-target='input']")
      const hidden = cb.querySelector("[data-combobox-target='hidden']")
      const results = cb.querySelector(".combobox-results")

      cb.setAttribute(
        "data-combobox-url-value",
        enabled ? `${base}?warehouse_id=${encodeURIComponent(id)}` : base
      )

      if (input) {
        input.disabled = !enabled
        input.placeholder = enabled ? "Escriba el nombre del producto" : "Elija un almacén primero"
      }
      if (!enabled) {
        if (input) input.value = ""
        if (hidden) hidden.value = ""
        if (results) results.innerHTML = ""
        cb.classList.remove("is-open")
      }
    })
  }

  // -------------------------------------------------------------------------
  // Forma de pago: Contado disables the installment fields (they then submit
  // nothing and the service defaults to a single installment); Cuotas enables.
  // -------------------------------------------------------------------------
  togglePaymentMode() {
    const cuotas =
      this.element.querySelector("input[name='payment_method']:checked")?.value === "cuotas"

    if (this.hasNumInstallmentsTarget) {
      this.numInstallmentsTarget.disabled = !cuotas
      if (!cuotas) this.numInstallmentsTarget.value = 1
    }
    if (this.hasIntervalDaysTarget) this.intervalDaysTarget.disabled = !cuotas
  }

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

    // The cloned product picker must inherit the current warehouse gating.
    this.syncWarehouseGating()
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

  // Client picker: show the selected client's document and enable the edit link.
  clientSelected(event) {
    const { document: doc, editPath } = event.detail
    if (this.hasClientDocTarget) this.clientDocTarget.textContent = doc || ""
    if (this.hasClientEditTarget && editPath) {
      this.clientEditTarget.href = editPath
      this.clientEditTarget.classList.remove("is-disabled")
      this.clientEditTarget.removeAttribute("aria-disabled")
    }
  }

  // Client picker cleared (input edited): clear the document and disable the edit link.
  clientCleared() {
    if (this.hasClientDocTarget) this.clientDocTarget.textContent = ""
    if (this.hasClientEditTarget) {
      this.clientEditTarget.removeAttribute("href")
      this.clientEditTarget.classList.add("is-disabled")
      this.clientEditTarget.setAttribute("aria-disabled", "true")
    }
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
