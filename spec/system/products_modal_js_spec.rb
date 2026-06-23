require "rails_helper"

# JS system specs for the Products modal (new/edit) + toast flash.
# Driver: headless_chrome (js: true). Skips when Chrome is absent.
# Mirrors spec/system/clients_modal_js_spec.rb (same modal/toast infrastructure).

RSpec.describe "Products modal (JS)", type: :system, js: true do
  let(:admin)     { create(:user, :administrador) }
  let(:warehouse) { create(:warehouse, name: "Central") }

  before do
    warehouse
    system_login_as(admin)
  end

  it "opens the new-product form in a modal without leaving the index" do
    visit products_path
    click_link "Nuevo producto"

    expect(page).to have_css("dialog.modal[open]", wait: 10)
    within("dialog.modal") do
      expect(page).to have_content("Nuevo producto")
      expect(page).to have_field("SKU")
    end
    expect(page).to have_current_path(products_path)

    find(".modal__close").click
    expect(page).to have_no_css("dialog.modal[open]")
  end

  it "creates a product from the modal, closing it and showing a toast" do
    visit products_path
    click_link "Nuevo producto"

    expect(page).to have_css("dialog.modal[open]", wait: 10)
    within("dialog.modal") do
      fill_in "SKU", with: "MODAL-001"
      fill_in "Nombre", with: "Modal Widget"
      fill_in "Marca", with: "ACME"
      find("#product_warehouse_id option", text: "Central").select_option
      fill_in "Stock", with: "5"
      fill_in "Precio base USD", with: "9.99"
      click_button "Crear producto"
    end

    within("#products") { expect(page).to have_content("Modal Widget", wait: 10) }
    expect(page).to have_css(".toast", text: "Producto creado correctamente.")
    expect(page).to have_no_css("dialog.modal[open]")
  end

  it "edits a product from the modal and updates its row in place" do
    product = create(:product, name: "Before Edit", warehouse: warehouse)
    visit products_path

    within("##{ActionView::RecordIdentifier.dom_id(product)}") { click_link "Editar" }

    expect(page).to have_css("dialog.modal[open]", wait: 10)
    within("dialog.modal") do
      fill_in "Nombre", with: "After Edit"
      click_button "Actualizar producto"
    end

    within("#products") do
      expect(page).to have_content("After Edit", wait: 10)
      expect(page).to have_no_content("Before Edit")
    end
    expect(page).to have_css(".toast", text: "Producto actualizado correctamente.")
  end
end
