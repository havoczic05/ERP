require "rails_helper"

# JS system specs for the Clients modal (new/edit) + toast flash.
#
# Driver: headless_chrome (js: true). Skips when Chrome is absent.
# Exercises the real Turbo Frame modal, the <dialog> Stimulus controller and
# the Turbo Stream responses (close modal + update row + append toast).
#
# Authentication: real UI login via system_login_as (the in-process stub does
# not cross into the Capybara/Puma server thread under Selenium).
#
# NOTE: each create/update assertion waits on the PERSISTENT table row first
# (it never auto-dismisses) so a cold dev-mode template compilation on the first
# Turbo Stream POST is absorbed before the transient toast is checked.

RSpec.describe "Clients modal (JS)", type: :system, js: true do
  let(:admin) { create(:user, :administrador) }

  before { system_login_as(admin) }

  it "opens the new-client form in a modal without leaving the index" do
    visit clients_path
    click_link "Nuevo cliente"

    expect(page).to have_css("dialog.modal[open]")
    within("dialog.modal") do
      expect(page).to have_content("Nuevo cliente")
      expect(page).to have_field("Nombre completo")
    end
    expect(page).to have_current_path(clients_path)

    # The × button closes the modal (and clears the frame so it can reopen).
    find(".modal__close").click
    expect(page).to have_no_css("dialog.modal[open]")
  end

  it "creates a client from the modal, closing it and showing a toast" do
    visit clients_path
    click_link "Nuevo cliente"

    expect(page).to have_css("dialog.modal[open]", wait: 10) # wait until showModal() promoted it
    within("dialog.modal") do
      fill_in "Nombre completo", with: "Modal Client SA"
      find("#client_document_type option", text: "Ruc").select_option
      fill_in "Número de documento", with: "20123123129"
      fill_in "Teléfono", with: "999111222"
      click_button "Crear cliente"
    end

    within("#clients") { expect(page).to have_content("Modal Client SA", wait: 10) }
    expect(page).to have_css(".toast", text: "Cliente creado correctamente.")
    expect(page).to have_no_css("dialog.modal[open]")
  end

  it "edits a client from the modal and updates its row in place" do
    client = create(:client, :ruc_client, full_name: "Before Edit")
    visit clients_path

    within("##{ActionView::RecordIdentifier.dom_id(client)}") { click_link "Editar" }

    within("dialog.modal") do
      fill_in "Nombre completo", with: "After Edit"
      click_button "Actualizar cliente"
    end

    within("#clients") do
      expect(page).to have_content("After Edit", wait: 10)
      expect(page).to have_no_content("Before Edit")
    end
    expect(page).to have_css(".toast", text: "Cliente actualizado correctamente.")
  end

  it "auto-dismisses the toast after its timeout" do
    visit clients_path
    click_link "Nuevo cliente"

    expect(page).to have_css("dialog.modal[open]")
    within("dialog.modal") do
      fill_in "Nombre completo", with: "Toast Client"
      find("#client_document_type option", text: "Ruc").select_option
      fill_in "Número de documento", with: "20123123130"
      fill_in "Teléfono", with: "999111333"
      click_button "Crear cliente"
    end

    within("#clients") { expect(page).to have_content("Toast Client", wait: 10) }
    expect(page).to have_css(".toast", text: "Cliente creado correctamente.")
    expect(page).to have_no_css(".toast", wait: 6)
  end
end
