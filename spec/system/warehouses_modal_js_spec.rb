require "rails_helper"

# JS system specs for the Warehouses modal (new/edit) + toast flash.
# Driver: headless_chrome (js: true). Skips when Chrome is absent.
# Mirrors spec/system/clients_modal_js_spec.rb (same modal/toast infrastructure).

RSpec.describe "Warehouses modal (JS)", type: :system, js: true do
  let(:admin) { create(:user, :administrador) }

  before { system_login_as(admin) }

  it "opens the new-warehouse form in a modal without leaving the index" do
    visit warehouses_path
    click_link "Nuevo almacén"

    expect(page).to have_css("dialog.modal[open]", wait: 10)
    within("dialog.modal") do
      expect(page).to have_content("Nuevo almacén")
      expect(page).to have_field("Nombre")
    end
    expect(page).to have_current_path(warehouses_path)

    find(".modal__close").click
    expect(page).to have_no_css("dialog.modal[open]")
  end

  it "creates a warehouse from the modal, closing it and showing a toast" do
    visit warehouses_path
    click_link "Nuevo almacén"

    expect(page).to have_css("dialog.modal[open]", wait: 10)
    within("dialog.modal") do
      fill_in "Nombre", with: "Depósito Norte"
      fill_in "Ubicación", with: "Lima"
      click_button "Crear almacén"
    end

    within("#warehouses") { expect(page).to have_content("Depósito Norte", wait: 10) }
    expect(page).to have_css(".toast", text: "Almacén creado correctamente.")
    expect(page).to have_no_css("dialog.modal[open]")
  end

  it "edits a warehouse from the modal and updates its row in place" do
    warehouse = create(:warehouse, name: "Antes")
    visit warehouses_path

    within("##{ActionView::RecordIdentifier.dom_id(warehouse)}") { click_link "Editar" }

    expect(page).to have_css("dialog.modal[open]", wait: 10)
    within("dialog.modal") do
      fill_in "Nombre", with: "Después"
      click_button "Actualizar almacén"
    end

    within("#warehouses") do
      expect(page).to have_content("Después", wait: 10)
      expect(page).to have_no_content("Antes")
    end
    expect(page).to have_css(".toast", text: "Almacén actualizado correctamente.")
  end

  it "opens a read-only detail modal from Ver and switches to edit" do
    warehouse = create(:warehouse, name: "Ver Me Depot")
    visit warehouses_path

    within("##{ActionView::RecordIdentifier.dom_id(warehouse)}") { click_link "Ver" }

    expect(page).to have_css("dialog.modal[open]", wait: 10)
    within("dialog.modal") do
      expect(page).to have_content("Detalle del almacén")
      expect(page).to have_content("Ver Me Depot")
      click_link "Editar"
    end

    expect(page).to have_field("Nombre", with: "Ver Me Depot", wait: 10)
    within("dialog.modal") do
      fill_in "Nombre", with: "Editado Desde Ver"
      click_button "Actualizar almacén"
    end

    within("#warehouses") { expect(page).to have_content("Editado Desde Ver", wait: 10) }
    expect(page).to have_css(".toast", text: "Almacén actualizado correctamente.")
  end
end
