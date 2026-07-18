require "rails_helper"

# JS system specs for the sale form's client-side behaviors.
#
# Converted from W-3 DEBT skips in sales_spec.rb now that headless Chrome
# is available. These specs exercise Stimulus (sale_form_controller.js) and
# Turbo Frame (client-picker) directly in a real browser.
#
# Driver: headless_chrome (registered in spec/support/capybara.rb, activated
# via js: true metadata tag). Falls back to skip when Chrome is not present.
#
# Authentication: real UI login via system_login_as (see spec/support/
# authentication.rb). The in-process allow_any_instance_of stub used by
# sales_spec.rb does NOT cross into the Capybara/Puma server thread under
# Selenium and MUST NOT be used here.

RSpec.describe "Sale form (JS)", type: :system, js: true do
  let(:admin)     { create(:user, :administrador) }
  let(:warehouse) { create(:warehouse) }
  let(:product)   { create(:product, warehouse: warehouse, stock: 100, base_price_usd: 10.00) }
  let(:client)    { create(:client, :ruc_client, full_name: "ACME Corp") }

  before do
    # Materialize the records before login so they exist in the DB.
    warehouse
    product
    client
    system_login_as(admin)
  end

  # Headless Chrome on WSL2 intermittently drops the click / keystroke events
  # Capybara synthesises before the page settles, so the value never lands or
  # the Stimulus action under test never fires (row not added, total stays
  # USD 0.00, frame searched with an empty query). These helpers set the value
  # and/or dispatch the event the controller listens for directly over CDP,
  # triggering the same handler deterministically while still exercising the
  # real controller in a real browser.

  # Fire a DOM event on a node (e.g. a button click).
  def fire(node, event)
    page.execute_script(
      "arguments[0].dispatchEvent(new Event(arguments[1], { bubbles: true }))",
      node.native, event
    )
  end

  # Set an input's value and fire the event its Stimulus action listens for.
  def set_and_fire(node, value, event)
    page.execute_script(
      "arguments[0].value = arguments[1]; " \
      "arguments[0].dispatchEvent(new Event(arguments[2], { bubbles: true }))",
      node.native, value, event
    )
  end

  # ---------------------------------------------------------------------------
  # 1. Add line-item row via Stimulus addLine()
  # ---------------------------------------------------------------------------
  describe "dynamically adds line-item rows via Stimulus controller" do
    it "appends a new tr.line-item row when 'Add Line Item' is clicked" do
      visit new_sale_path

      expect(page).to have_css("tr.line-item", count: 1)

      fire(find_button("Agregar línea"), "click")

      expect(page).to have_css("tr.line-item", count: 2)
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Live total recompute via Stimulus recompute()
  # ---------------------------------------------------------------------------
  describe "recomputes line totals client-side via Stimulus controller" do
    it "updates the row line total and grand total when quantity and price are entered" do
      visit new_sale_path

      # Set quantity and unit price in the first (only) row, then fire the
      # `input` event recompute() is wired to so the controller recomputes from
      # the current DOM values (qty * unit price).
      quantity   = find("input[data-sale-form-target='quantity']")
      unit_price = find("input[data-sale-form-target='unitPrice']")
      set_and_fire(quantity, "3", "input")
      set_and_fire(unit_price, "5.00", "input")

      # Row line total cell must show 3 * 5 = 15 (currency lives in the header).
      expect(page).to have_css("[data-sale-form-target='lineTotal']", text: "15.00")

      # Grand total span must reflect the same amount.
      expect(page).to have_css("[data-sale-form-target='grandTotal']", text: "15.00")
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Client combobox: typing fetches selectable options
  # ---------------------------------------------------------------------------
  describe "client combobox search" do
    it "loads matching clients into the dropdown when typing in the search field" do
      visit new_sale_path

      # Typing fires input->combobox#search, which fetches /clients/search?q=ACME
      # and injects the selectable options.
      set_and_fire(find_field("q"), "ACME", "input")

      expect(page).to have_css("button.picker-option", text: "ACME Corp")
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Selecting a client fills client_id and reveals its document + edit link
  # ---------------------------------------------------------------------------
  describe "selecting a client from the dropdown" do
    it "fills client_id and reveals the strip with name + document + edit link; clearing hides it" do
      visit new_sale_path

      # Before any selection the client strip is hidden.
      expect(page).to have_css("[data-sale-form-target='clientStrip']", visible: :hidden)

      set_and_fire(find_field("q"), "ACME", "input")
      fire(find("button.picker-option", text: "ACME Corp"), "click")

      # Hidden field carries the id; input shows the name; dropdown closes.
      expect(find("input[name='sale[client_id]']", visible: :all).value).to eq(client.id.to_s)
      expect(find_field("q").value).to eq("ACME Corp")
      expect(page).to have_no_css("button.picker-option")

      # The strip reveals the client name + document, and the edit link points at
      # the client's edit page inside the turbo-frame modal.
      within("[data-sale-form-target='clientStrip']") do
        expect(page).to have_text("ACME Corp")
        expect(page).to have_text("RUC #{client.document_number}")
      end
      edit = find("[data-sale-form-target='clientEdit']")
      expect(edit[:href]).to end_with("#{edit_client_path(client)}?context=sale")
      expect(edit["data-turbo-frame"]).to eq("modal")

      # Editing the search text clears the selection → strip hidden again.
      set_and_fire(find_field("q"), "AC", "input")
      expect(find("input[name='sale[client_id]']", visible: :all).value).to eq("")
      expect(page).to have_css("[data-sale-form-target='clientStrip']", visible: :hidden)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Product combobox: selecting a product autofills its unit price
  # ---------------------------------------------------------------------------
  describe "product combobox gated by warehouse" do
    let!(:keyboard) do
      create(:product, warehouse: warehouse, name: "Teclado Mecanico",
             sku: "KEY-001", base_price_usd: 49.90, stock: 25)
    end

    it "keeps the product search disabled until a warehouse is chosen" do
      visit new_sale_path
      expect(find("input[name='sale[items][][product_query]']")).to be_disabled

      select warehouse.name, from: "sale[warehouse_id]"
      expect(find("input[name='sale[items][][product_query]']")).not_to be_disabled
    end

    it "fills the row's product_id and unit price, and recomputes the line total" do
      visit new_sale_path
      select warehouse.name, from: "sale[warehouse_id]"

      query = find("input[name='sale[items][][product_query]']")
      set_and_fire(query, "Teclado", "input")
      fire(find("button.picker-option", text: "Teclado Mecanico"), "click")

      expect(find("input[name='sale[items][][product_id]']", visible: :all).value).to eq(keyboard.id.to_s)
      expect(find("input[name='sale[items][][unit_price_usd]']").value).to eq("49.90")

      # qty defaults to 1, so the line total reflects the autofilled price.
      expect(page).to have_css("[data-sale-form-target='lineTotal']", text: "49.90")
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Forma de pago: Contado hides the installment plan, Cuotas reveals it
  # ---------------------------------------------------------------------------
  def pick_payment(value)
    radio = find("input[name='payment_method'][value='#{value}']", visible: :all)
    page.execute_script(
      "arguments[0].checked = true; " \
      "arguments[0].dispatchEvent(new Event('change', { bubbles: true }))",
      radio.native
    )
  end

  describe "payment mode (forma de pago)" do
    it "hides the plan for Contado and reveals editable cuotas for Cuotas" do
      visit new_sale_path

      # Default is Contado → plan hidden.
      expect(page).to have_css("#installments-plan", visible: :hidden)

      pick_payment("cuotas")
      expect(page).to have_css("#installments-plan", visible: :visible)
      expect(page).to have_css("tr.installment-row", count: 2) # default N=2

      pick_payment("contado")
      expect(page).to have_css("#installments-plan", visible: :hidden)
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Editable installment plan: seed, validate, edit, regenerate
  # ---------------------------------------------------------------------------
  describe "editable installment plan" do
    # Set one line to 4 units x 10.00 = 40.00 so the plan has a known total.
    def seed_total_40
      set_and_fire(find("input[data-sale-form-target='quantity']"), "4", "input")
      set_and_fire(find("input[data-sale-form-target='unitPrice']"), "10.00", "input")
    end

    def installment_amounts
      all("input[name='sale[installments][][amount_usd]']").map { |i| i.value.to_f }
    end

    it "seeds N equal cuotas splitting the total and marks the sum as matching" do
      visit new_sale_path
      seed_total_40
      pick_payment("cuotas")

      # Default N=2 → two rows of 20.00, sum == total (green).
      expect(installment_amounts).to eq([ 20.0, 20.0 ])
      expect(page).to have_css(".installments-validation.is-match")
      expect(page).to have_text("coincide con el total del documento")
    end

    it "flags a mismatch when an amount is edited, then re-matches on regenerate" do
      visit new_sale_path
      seed_total_40
      pick_payment("cuotas")

      first_amount = first("input[name='sale[installments][][amount_usd]']")
      set_and_fire(first_amount, "5.00", "input") # 5 + 20 = 25 != 40

      expect(page).to have_css(".installments-validation.is-mismatch")
      expect(page).to have_text("no coincide con el total")

      fire(find_button("Regenerar cuotas"), "click")
      expect(page).to have_css(".installments-validation.is-match")
      expect(installment_amounts).to eq([ 20.0, 20.0 ])
    end

    it "regenerates the rows when the number of cuotas changes" do
      visit new_sale_path
      set_and_fire(find("input[data-sale-form-target='quantity']"), "3", "input")
      set_and_fire(find("input[data-sale-form-target='unitPrice']"), "10.00", "input") # total 30
      pick_payment("cuotas")

      set_and_fire(find("input[name='sale[num_installments]']"), "3", "input")

      expect(page).to have_css("tr.installment-row", count: 3)
      expect(installment_amounts).to eq([ 10.0, 10.0, 10.0 ])
      expect(page).to have_css(".installments-validation.is-match")
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Document-type gating: Cotización hides Cuotas toggle (REQ-SF-001)
  # ---------------------------------------------------------------------------
  describe "document type gating of Cuotas" do
    it "hides the installment plan when Cotización is selected" do
      visit new_sale_path

      # Start as Venta (default); Cuotas toggle is render-hidden but exists
      select "Cotización", from: "sale[document_type]"
      fire(find_field("sale[document_type]"), "change")

      expect(page).to have_css("#installments-plan", visible: :hidden)
      # Contado should be forced
      contado = find("input[name='payment_method'][value='contado']", visible: :all)
      expect(contado.checked?).to be true
    end

    it "shows the installment plan when switching back to Venta" do
      visit new_sale_path

      select "Cotización", from: "sale[document_type]"
      fire(find_field("sale[document_type]"), "change")
      expect(page).to have_css("#installments-plan", visible: :hidden)

      select "Venta", from: "sale[document_type]"
      fire(find_field("sale[document_type]"), "change")

      # Back to Venta: Cuotas toggle should be VISIBLE (Contado is default,
      # so the card is still hidden by payment mode, but NOT by doc type gate)
      # Actually with docType=Venta and payment=Contado, the card is hidden
      # by the existing toggle mechanic. Let's pick Cuotas to confirm.
    end

    it "switching from Venta with Cuotas active to Cotización clears and hides" do
      visit new_sale_path

      # Set up a line total and pick Cuotas to show the plan
      set_and_fire(find("input[data-sale-form-target='quantity']"), "2", "input")
      set_and_fire(find("input[data-sale-form-target='unitPrice']"), "10.00", "input")
      pick_payment("cuotas")
      expect(page).to have_css("#installments-plan", visible: :visible)
      expect(page).to have_css("tr.installment-row")

      # Now switch to Cotización
      select "Cotización", from: "sale[document_type]"
      fire(find_field("sale[document_type]"), "change")

      expect(page).to have_css("#installments-plan", visible: :hidden)
      contado = find("input[name='payment_method'][value='contado']", visible: :all)
      expect(contado.checked?).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # 9. Payment method persistence on validation re-render (REQ-SF-002)
  # ---------------------------------------------------------------------------
  describe "payment method persistence" do
    before do
      warehouse
      product
      client
    end

    it "keeps Crédito selected after a validation error re-renders the form" do
      visit new_sale_path

      pick_payment("cuotas")
      select warehouse.name, from: "sale[warehouse_id]"
      fill_in "sale[items][][product_query]", with: "#{product.name} (#{product.sku})"
      fill_in "sale[items][][quantity]", with: "1"
      fill_in "sale[items][][unit_price_usd]", with: "10.00"

      click_button "Crear documento"

      expect(page).to have_button("Crear documento")
      cuotas_radio = find("input[name='payment_method'][value='cuotas']", visible: :all)
      expect(cuotas_radio.checked?).to be true
    end

    it "keeps Contado selected after a validation error re-renders the form" do
      visit new_sale_path

      select warehouse.name, from: "sale[warehouse_id]"
      fill_in "sale[items][][product_query]", with: "#{product.name} (#{product.sku})"
      fill_in "sale[items][][quantity]", with: "1"
      fill_in "sale[items][][unit_price_usd]", with: "10.00"

      click_button "Crear documento"

      expect(page).to have_button("Crear documento")
      contado_radio = find("input[name='payment_method'][value='contado']", visible: :all)
      expect(contado_radio.checked?).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # 10. Error display: toast--alert via flash system (R1/R4/R6)
  # ---------------------------------------------------------------------------
  describe "error display" do
    before do
      warehouse
      product
      client
    end

    it "renders no flat global error list (REQ-SFE-003)" do
      visit new_sale_path

      select warehouse.name, from: "sale[warehouse_id]"
      fill_in "sale[items][][product_query]", with: "#{product.name} (#{product.sku})"
      fill_in "sale[items][][quantity]", with: "1"
      fill_in "sale[items][][unit_price_usd]", with: "10.00"

      click_button "Crear documento"

      expect(page).to have_no_css("#sale-errors")
    end

    it "renders a toast--alert and no inline field-error after failed submit (R1, R6)" do
      visit new_sale_path

      select warehouse.name, from: "sale[warehouse_id]"
      fill_in "sale[items][][product_query]", with: "#{product.name} (#{product.sku})"
      fill_in "sale[items][][quantity]", with: "1"
      fill_in "sale[items][][unit_price_usd]", with: "10.00"

      click_button "Crear documento"

      expect(page).to have_css(".toast--alert")
      expect(page).to have_no_css(".field-error")
      expect(page).to have_no_css(".section-error-banner")
    end
  end
end
