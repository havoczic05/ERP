require "rails_helper"

# JS system specs for stock validation on the sales form (change: stock-validation).
#
# Exercises client-side stock feedback (SF-01 through SF-04) and multi-row /
# edge-case scenarios, using the real browser to confirm Stimulus
# (sale_form_controller.js) reacts correctly to combobox:select and
# quantity-input changes.
#
# Driver: headless_chrome (spec/support/capybara.rb), activated via js: true.

RSpec.describe "Stock validation (JS)", type: :system, js: true do
  let(:admin)     { create(:user, :administrador) }
  let(:warehouse) { create(:warehouse) }
  let(:client)    { create(:client, :ruc_client, full_name: "ACME Corp") }

  # Products with controlled stock values.
  let!(:product_stocked) do
    create(:product, warehouse: warehouse, name: "Teclado Mecanico",
           sku: "KEY-001", stock: 15, base_price_usd: 49.90)
  end
  let!(:product_low) do
    create(:product, warehouse: warehouse, name: "Mouse USB",
           sku: "MOU-001", stock: 10, base_price_usd: 20.00)
  end
  let!(:product_zero) do
    create(:product, warehouse: warehouse, name: "Empty Box",
           sku: "EMP-001", stock: 0, base_price_usd: 5.00)
  end

  before do
    warehouse
    client
    system_login_as(admin)
  end

  # ---------------------------------------------------------------------------
  # Browser helpers (matching the existing sale-form JS spec pattern).
  # ---------------------------------------------------------------------------
  def fire(node, event)
    page.execute_script(
      "arguments[0].dispatchEvent(new Event(arguments[1], { bubbles: true }))",
      node.native, event
    )
  end

  def set_and_fire(node, value, event)
    page.execute_script(
      "arguments[0].value = arguments[1]; " \
      "arguments[0].dispatchEvent(new Event(arguments[2], { bubbles: true }))",
      node.native, value, event
    )
  end

  # Select a product in the given row (0-indexed) via the combobox.
  def select_product(name, row_index = 0)
    select warehouse.name, from: "sale[warehouse_id]"
    inputs = all("input[name='sale[items][][product_query]']")
    query  = inputs[row_index]
    set_and_fire(query, name, "input")
    fire(find("button.picker-option", text: name), "click")
  end

  # Set quantity in the given row (0-indexed).
  def set_quantity(value, row_index = 0)
    qty = all("[data-sale-form-target='quantity']")[row_index]
    set_and_fire(qty, value.to_s, "input")
  end

  # ---------------------------------------------------------------------------
  # SF-01 — Stock display on product select
  # ---------------------------------------------------------------------------
  describe "stock display on product select (SF-01)" do
    it "shows available stock when a product is selected" do
      visit new_sale_path
      select_product("Teclado Mecanico")

      expect(page).to have_css("[data-sale-form-target='stockHint']", text: "Stock disponible: 15")
    end

    it "persists stock per row in row.dataset.stock" do
      visit new_sale_path
      select_product("Teclado Mecanico")

      stock_val = page.evaluate_script(
        "document.querySelectorAll('tr.line-item')[0].dataset.stock"
      )
      expect(stock_val).to eq("15")
    end
  end

  # ---------------------------------------------------------------------------
  # SF-02 — Submit blocked when quantity exceeds stock
  # ---------------------------------------------------------------------------
  describe "submit blocked on over-stock (SF-02)" do
    it "disables the submit button when quantity > stock" do
      visit new_sale_path
      select_product("Mouse USB")        # stock = 10
      set_quantity(12)                   # 12 > 10

      expect(page).to have_button("Crear documento", disabled: true)
    end

    it "applies the is-over class to the row" do
      visit new_sale_path
      select_product("Mouse USB")
      set_quantity(12)

      row = first("tr.line-item")
      expect(row[:class]).to include("is-over")
    end

    it "sets the quantity input max attribute to the stock value" do
      visit new_sale_path
      select_product("Mouse USB")

      qty = first("[data-sale-form-target='quantity']")
      expect(qty["max"]).to eq("10")
    end
  end

  # ---------------------------------------------------------------------------
  # SF-02b — Submit re-enabled when quantity corrected
  # ---------------------------------------------------------------------------
  describe "submit re-enabled on correction (SF-02b)" do
    it "enables the submit button and removes is-over when quantity is reduced to ≤ stock" do
      visit new_sale_path
      select_product("Mouse USB")        # stock = 10
      set_quantity(12)                   # over

      expect(page).to have_button("Crear documento", disabled: true)

      set_quantity("8")                  # under

      expect(page).to have_button("Crear documento", disabled: false)
      row = first("tr.line-item")
      expect(row[:class]).not_to include("is-over")
    end
  end

  # ---------------------------------------------------------------------------
  # SF-03 — Per-row error message
  # ---------------------------------------------------------------------------
  describe "per-row error message (SF-03)" do
    it "shows 'Cantidad excede stock disponible (X)' when quantity > stock" do
      visit new_sale_path
      select_product("Mouse USB")        # stock = 10
      set_quantity(12)                   # over

      expect(page).to have_css(
        "[data-sale-form-target='stockError']",
        text: "Cantidad excede stock disponible (10)",
        visible: :visible
      )
    end

    it "hides the error message when quantity is corrected" do
      visit new_sale_path
      select_product("Mouse USB")
      set_quantity(12)

      expect(page).to have_css("[data-sale-form-target='stockError']", visible: :visible)

      set_quantity("5")

      expect(page).to have_css("[data-sale-form-target='stockError']", visible: :hidden)
    end
  end

  # ---------------------------------------------------------------------------
  # SF-04 — Cotización exemption (no stock validation)
  # ---------------------------------------------------------------------------
  describe "cotización exemption (SF-04)" do
    it "does not block submit when document_type is cotización, even with over-stock qty" do
      visit new_sale_path

      # Switch to cotización first
      select "Cotización", from: "sale[document_type]"
      fire(find_field("sale[document_type]"), "change")

      select_product("Mouse USB")
      set_quantity(12) # exceeds stock=10

      expect(page).to have_button("Crear documento", disabled: false)
      expect(page).to have_no_css("[data-sale-form-target='stockError']", visible: :visible)
    end

    it "re-enables validation when switching back to Venta" do
      visit new_sale_path

      # Start as Venta, enter over-stock → blocked
      select_product("Mouse USB")
      set_quantity(12)
      expect(page).to have_button("Crear documento", disabled: true)

      # Switch to Cotización → unblocked
      select "Cotización", from: "sale[document_type]"
      fire(find_field("sale[document_type]"), "change")
      expect(page).to have_button("Crear documento", disabled: false)

      # Switch back to Venta → re-blocked
      select "Venta", from: "sale[document_type]"
      fire(find_field("sale[document_type]"), "change")
      expect(page).to have_button("Crear documento", disabled: true)
    end
  end

  # ---------------------------------------------------------------------------
  # Multi-row stock validation
  # ---------------------------------------------------------------------------
  describe "multi-row validation" do
    it "blocks submit when any single row exceeds stock" do
      visit new_sale_path

      # Row 0: valid
      select_product("Teclado Mecanico", 0) # stock=15
      set_quantity(5, 0)

      # Add second row
      fire(find_button("Agregar línea"), "click")
      expect(page).to have_css("tr.line-item", count: 2)

      # Row 1: overstock
      select_product("Mouse USB", 1)         # stock=10
      set_quantity(11, 1)                    # over

      expect(page).to have_button("Crear documento", disabled: true)
    end

    it "enables submit only when all rows are within stock" do
      visit new_sale_path

      # Row 0: valid
      select_product("Teclado Mecanico", 0)
      set_quantity(5, 0)

      # Row 1: overstock first
      fire(find_button("Agregar línea"), "click")
      select_product("Mouse USB", 1)
      set_quantity(11, 1)                    # over
      expect(page).to have_button("Crear documento", disabled: true)

      # Fix row 1
      set_quantity("5", 1)
      expect(page).to have_button("Crear documento", disabled: false)
    end

    it "shows per-row stock hints independently" do
      visit new_sale_path

      select_product("Teclado Mecanico", 0)  # stock=15
      fire(find_button("Agregar línea"), "click")
      select_product("Mouse USB", 1)          # stock=10

      hints = all("[data-sale-form-target='stockHint']")
      expect(hints[0].text).to eq("Stock disponible: 15")
      expect(hints[1].text).to eq("Stock disponible: 10")
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases
  # ---------------------------------------------------------------------------
  describe "edge cases" do
    it "blocks submit and shows error when stock is 0" do
      visit new_sale_path
      select_product("Empty Box")           # stock = 0

      expect(page).to have_css("[data-sale-form-target='stockHint']", text: "Stock disponible: 0")
      # Any positive quantity exceeds stock 0
      set_quantity(1)
      expect(page).to have_button("Crear documento", disabled: true)
      expect(page).to have_css(
        "[data-sale-form-target='stockError']",
        text: "Cantidad excede stock disponible (0)",
        visible: :visible
      )
    end

    it "does not block submit for a row without a product selected" do
      visit new_sale_path

      # No product selected → no stock dataset → no validation
      set_quantity(999)
      expect(page).to have_button("Crear documento", disabled: false)
      expect(page).to have_no_css("[data-sale-form-target='stockError']", visible: :visible)
    end

    it "does not apply stock validation for cotizaciones, even with stock=0" do
      visit new_sale_path

      select "Cotización", from: "sale[document_type]"
      fire(find_field("sale[document_type]"), "change")

      select_product("Empty Box")           # stock = 0
      set_quantity(5)                       # would be over for venta

      expect(page).to have_button("Crear documento", disabled: false)
      expect(page).to have_no_css("[data-sale-form-target='stockError']", visible: :visible)
    end
  end
end
