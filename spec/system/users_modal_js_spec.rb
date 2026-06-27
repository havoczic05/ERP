require "rails_helper"

# JS system specs for the Users modal (new/edit) + toast flash.
# Driver: headless_chrome (js: true). Skips when Chrome is absent.
# Mirrors spec/system/clients_modal_js_spec.rb (same modal/toast infrastructure).

RSpec.describe "Users modal (JS)", type: :system, js: true do
  let(:admin) { create(:user, :administrador) }

  before { system_login_as(admin) }

  it "opens the new-user form in a modal without leaving the index" do
    visit users_path
    wait_until_js_booted
    click_link "Nuevo usuario"

    expect(page).to have_css("dialog.modal[open]", wait: MODAL_WAIT)
    within("dialog.modal") do
      expect(page).to have_content("Nuevo usuario")
      expect(page).to have_field("Correo electrónico")
    end
    expect(page).to have_current_path(users_path)

    find(".modal__close").click
    expect(page).to have_no_css("dialog.modal[open]")
  end

  it "creates a user from the modal, closing it and showing a toast" do
    visit users_path
    wait_until_js_booted
    click_link "Nuevo usuario"

    expect(page).to have_css("dialog.modal[open]", wait: MODAL_WAIT)
    within("dialog.modal") do
      fill_in "Correo electrónico", with: "nuevo@example.com"
      find("#user_role option", text: "Vendedor").select_option
      fill_in "Contraseña", with: "password123"
      fill_in "Confirmación de contraseña", with: "password123"
      click_button "Crear usuario"
    end

    within("#users") { expect(page).to have_content("nuevo@example.com", wait: MODAL_WAIT) }
    expect(page).to have_css(".toast", text: "Usuario creado correctamente.")
    expect(page).to have_no_css("dialog.modal[open]")
  end

  it "edits a user from the modal and updates its row in place" do
    user = create(:user, :vendedor, email: "antes@example.com")
    visit users_path
    wait_until_js_booted

    within("##{ActionView::RecordIdentifier.dom_id(user)}") { click_link "Editar" }

    expect(page).to have_css("dialog.modal[open]", wait: MODAL_WAIT)
    within("dialog.modal") do
      fill_in "Correo electrónico", with: "despues@example.com"
      click_button "Actualizar usuario"
    end

    within("#users") do
      expect(page).to have_content("despues@example.com", wait: MODAL_WAIT)
      expect(page).to have_no_content("antes@example.com")
    end
    expect(page).to have_css(".toast", text: "Usuario actualizado correctamente.")
  end

  it "opens a read-only detail modal from Ver and switches to edit" do
    user = create(:user, :vendedor, email: "verme@example.com")
    visit users_path
    wait_until_js_booted

    within("##{ActionView::RecordIdentifier.dom_id(user)}") { click_link "Ver" }

    expect(page).to have_css("dialog.modal[open]", wait: MODAL_WAIT)
    within("dialog.modal") do
      expect(page).to have_content("Detalle del usuario")
      expect(page).to have_content("verme@example.com")
      click_link "Editar"
    end

    expect(page).to have_field("Correo electrónico", with: "verme@example.com", wait: MODAL_WAIT)
    within("dialog.modal") do
      fill_in "Correo electrónico", with: "editado@example.com"
      click_button "Actualizar usuario"
    end

    within("#users") { expect(page).to have_content("editado@example.com", wait: MODAL_WAIT) }
    expect(page).to have_css(".toast", text: "Usuario actualizado correctamente.")
  end
end
