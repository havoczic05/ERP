require "rails_helper"

# JS system specs for the Company Settings edit modal + toast.
# Driver: headless_chrome (js: true). Skips when Chrome is absent.

RSpec.describe "Company settings modal (JS)", type: :system, js: true do
  let(:admin) { create(:user, :administrador) }

  before do
    CompanySettings.instance.update!(razon_social: "Empresa Test SAC", ruc: "20123456789",
                                     direccion: "Av. Principal 100", telefono: "012345678")
    system_login_as(admin)
  end

  it "opens the edit form in a modal without leaving the page" do
    visit company_settings_path
    click_link "Editar configuración"

    expect(page).to have_css("dialog.modal[open]", wait: 10)
    within("dialog.modal") do
      expect(page).to have_content("Editar configuración")
      expect(page).to have_field("Razón social")
    end
    expect(page).to have_current_path(company_settings_path)
  end

  it "updates the settings from the modal, closing it and showing a toast" do
    visit company_settings_path
    click_link "Editar configuración"

    expect(page).to have_css("dialog.modal[open]", wait: 10)
    within("dialog.modal") do
      fill_in "Razón social", with: "Nueva Empresa SAC"
      click_button "Guardar cambios"
    end

    within("#company_settings") { expect(page).to have_content("Nueva Empresa SAC", wait: 10) }
    expect(page).to have_css(".toast", text: "Configuración actualizada.")
    expect(page).to have_no_css("dialog.modal[open]")
  end
end
