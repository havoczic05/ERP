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
    "clientStrip",
    "clientName",
    "clientDoc",
    "clientEdit",
    "installmentsSection",
    "installmentsBody",
    "installmentsValidation",
    "installmentsSum",
    "documentType",
  ]

  static values = { productSearchUrl: String }

  // Upper bound on an editable plan — mirrors SaleCreationService::MAX_INSTALLMENTS.
  static MAX_INSTALLMENTS = 4

  connect() {
    this.togglePaymentMode()
    this.syncWarehouseGating()
    this.recomputeAll()
  }

  // Recompute every line-item row (and the grand total). Used on connect so a
  // preloaded form (e.g. the cotizacion→venta convert form) shows correct
  // line/grand totals immediately, before the user touches any input.
  recomputeAll() {
    if (!this.hasLineItemsBodyTarget) return
    this.lineItemsBodyTarget
      .querySelectorAll("tr.line-item")
      .forEach((row) => this.recomputeRow(row))
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
  // Document type: Cotización hides the Cuotas toggle entirely because
  // cotizaciones carry no installments (REQ-SF-001). Switching to Venta
  // restores the normal toggle behavior.
  // -------------------------------------------------------------------------
  documentTypeChanged() {
    const docType = this.hasDocumentTypeTarget ? this.documentTypeTarget.value : ""
    const isCotizacion = docType === "cotizacion"

    if (!this.hasInstallmentsSectionTarget) return

    if (isCotizacion) {
      this.installmentsSectionTarget.hidden = true
      this.setInstallmentsEnabled(false)

      // Force Contado radio
      const contado = this.element.querySelector("input[name='payment_method'][value='contado']")
      if (contado) {
        contado.checked = true
        contado.dispatchEvent(new Event("change", { bubbles: true }))
      }
    } else {
      // Venta: restore normal toggle behavior — check the current radio state
      this.togglePaymentMode()
    }
  }

  // -------------------------------------------------------------------------
  // Forma de pago: Contado hides the installment plan and disables its inputs
  // so nothing installments-related is submitted (the service then defaults to
  // a single installment); Cuotas reveals the editable plan and seeds it.
  // -------------------------------------------------------------------------
  togglePaymentMode() {
    const cuotas =
      this.element.querySelector("input[name='payment_method']:checked")?.value === "cuotas"

    if (!this.hasInstallmentsSectionTarget) return

    this.installmentsSectionTarget.hidden = !cuotas
    this.setInstallmentsEnabled(cuotas)

    if (!cuotas) return
    // Entering Cuotas: seed rows the first time, otherwise just re-validate the
    // plan against the current total (line items may have changed meanwhile).
    if (this.installmentsBodyTarget.children.length === 0) {
      this.generateInstallments()
    } else {
      this.validateInstallments()
    }
  }

  // Disabled inputs are not submitted, so Contado never sends installments[].
  setInstallmentsEnabled(enabled) {
    this.installmentsSectionTarget
      .querySelectorAll("input, select")
      .forEach((el) => { el.disabled = !enabled })
  }

  // -------------------------------------------------------------------------
  // Plan de cuotas: generate / regenerate / validate the editable installments
  // -------------------------------------------------------------------------

  // Rebuild the rows from N + interval + the current grand total. Splits the
  // total into equal parts (truncated to cents) with the last row absorbing the
  // remainder, mirroring SaleCreationService's auto-generation, then lets the
  // user edit each fecha/monto.
  generateInstallments() {
    if (!this.hasInstallmentsBodyTarget) return

    const num = this.installmentCount()
    const interval = parseInt(this.intervalDaysTarget?.value, 10) || 30
    const total = this.computeGrandTotal()

    const base = Math.floor((total / num) * 100) / 100
    const amounts = Array.from({ length: num }, () => base)
    amounts[num - 1] = Math.round((total - base * (num - 1)) * 100) / 100

    const today = new Date()
    const start = new Date(today.getFullYear(), today.getMonth(), today.getDate())

    this.installmentsBodyTarget.innerHTML = ""
    amounts.forEach((amount, index) => {
      const due = new Date(start)
      due.setDate(due.getDate() + interval * (index + 1))
      this.installmentsBodyTarget.appendChild(this.buildInstallmentRow(index + 1, due, amount))
    })

    this.validateInstallments()
  }

  regenerateInstallments() {
    if (this.installmentsSectionTarget?.hidden) return
    this.generateInstallments()
  }

  // Clamp the requested installment count into 1..MAX.
  installmentCount() {
    const raw = parseInt(this.numInstallmentsTarget?.value, 10) || 1
    return Math.min(Math.max(raw, 1), this.constructor.MAX_INSTALLMENTS)
  }

  buildInstallmentRow(number, dueDate, amount) {
    const row = document.createElement("tr")
    row.className = "installment-row"
    row.innerHTML = `
      <td class="col-num num" data-label="Cuota">${number}</td>
      <td data-label="Vencimiento"><input type="date" name="sale[installments][][due_date]" value="${this.isoDate(dueDate)}"
                 data-action="input->sale-form#validateInstallments"></td>
      <td data-label="Monto (USD)"><input type="number" step="0.01" min="0" name="sale[installments][][amount_usd]"
                 value="${amount.toFixed(2)}" data-sale-form-target="installmentAmount"
                 data-action="input->sale-form#validateInstallments"></td>
      <td data-label="Estado"><span class="badge badge--warning">Pendiente</span></td>
    `
    return row
  }

  // Local-timezone YYYY-MM-DD (avoids the UTC shift toISOString would cause).
  isoDate(date) {
    const y = date.getFullYear()
    const m = String(date.getMonth() + 1).padStart(2, "0")
    const d = String(date.getDate()).padStart(2, "0")
    return `${y}-${m}-${d}`
  }

  // Sum the editable amounts and flag whether the plan matches the total.
  validateInstallments() {
    if (!this.hasInstallmentsSumTarget) return

    const sum = Array.from(
      this.installmentsBodyTarget.querySelectorAll("input[name='sale[installments][][amount_usd]']")
    ).reduce((acc, input) => acc + (parseFloat(input.value) || 0), 0)

    const total = this.computeGrandTotal()
    const matches = Math.round(sum * 100) === Math.round(total * 100)

    this.installmentsSumTarget.textContent = matches
      ? `Suma de cuotas: ${this.formatMoney(sum)} — coincide con el total del documento`
      : `Suma de cuotas: ${this.formatMoney(sum)} — no coincide con el total (${this.formatMoney(total)})`

    if (this.hasInstallmentsValidationTarget) {
      this.installmentsValidationTarget.classList.toggle("is-match", matches)
      this.installmentsValidationTarget.classList.toggle("is-mismatch", !matches)
    }
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
    if (lineTotalCell) lineTotalCell.textContent = this.formatAmount(qty * price)

    this.updateGrandTotal()
  }

  // "1,250.00" — thousands-separated, always 2 decimals, no currency. Used in
  // the item rows, where the column header already carries the "(USD)" unit.
  formatAmount(amount) {
    return amount.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  }

  // "USD 1,250.00" — the standalone document total keeps the currency prefix.
  formatMoney(amount) {
    return `USD ${this.formatAmount(amount)}`
  }

  // -------------------------------------------------------------------------
  // Sum all row line totals and display in grandTotal target
  // -------------------------------------------------------------------------
  updateGrandTotal() {
    const total = this.computeGrandTotal()
    if (this.hasGrandTotalTarget) this.grandTotalTarget.textContent = this.formatMoney(total)

    // Keep the installment plan's validation in sync when the total changes.
    if (this.hasInstallmentsSectionTarget && !this.installmentsSectionTarget.hidden) {
      this.validateInstallments()
    }
  }

  // Grand total (Number) computed from the current line-item rows.
  computeGrandTotal() {
    let total = 0
    this.lineItemsBodyTarget.querySelectorAll("tr.line-item").forEach((row) => {
      const qty = parseFloat(row.querySelector("[data-sale-form-target='quantity']")?.value) || 0
      const price = parseFloat(row.querySelector("[data-sale-form-target='unitPrice']")?.value) || 0
      total += qty * price
    })
    return total
  }

  // -------------------------------------------------------------------------
  // combobox:select reactions
  // -------------------------------------------------------------------------

  // Client picker: reveal the selected-client strip with its name, document,
  // and a link to edit it.
  clientSelected(event) {
    const { label, document: doc, editPath } = event.detail
    if (this.hasClientNameTarget) this.clientNameTarget.textContent = label || ""
    if (this.hasClientDocTarget) this.clientDocTarget.textContent = doc || ""
    // context=sale so the edit modal's save refreshes the strip in place (not a new tab).
    if (this.hasClientEditTarget && editPath) this.clientEditTarget.href = `${editPath}?context=sale`
    if (this.hasClientStripTarget) this.clientStripTarget.hidden = false
  }

  // Client picker cleared (input edited): hide the strip and drop the edit link.
  clientCleared() {
    if (this.hasClientNameTarget) this.clientNameTarget.textContent = ""
    if (this.hasClientDocTarget) this.clientDocTarget.textContent = ""
    if (this.hasClientEditTarget) this.clientEditTarget.removeAttribute("href")
    if (this.hasClientStripTarget) this.clientStripTarget.hidden = true
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
