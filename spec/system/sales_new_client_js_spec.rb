require "rails_helper"

# JS system spec for creating a client inline from the sale form and having it
# auto-selected into the client combobox (without reloading the half-entered
# sale). Exercises the modal, clients#create (context: sale) and the
# client_autoselect_controller bridge in a real browser.
#
# Driver: headless_chrome (js: true). Auth via system_login_as (see
# spec/support/capybara.rb / authentication.rb).

RSpec.describe "Nuevo cliente desde la venta (JS)", type: :system, js: true do
  let(:admin)     { create(:user, :administrador) }
  let(:warehouse) { create(:warehouse) }

  before do
    warehouse # materialize before login (visible to the Puma thread)
    system_login_as(admin)
  end

  it "crea un cliente en el modal y lo autoselecciona en la venta" do
    visit new_sale_path
    wait_until_js_booted

    click_link "Nuevo" # el botón "+ Nuevo" pegado al buscador de cliente
    expect(page).to have_css("dialog.modal[open]", wait: MODAL_WAIT)

    within("dialog.modal") do
      fill_in "Nombre completo", with: "Cliente Nuevo SAC"
      select "Dni", from: "Tipo de documento"
      fill_in "Número de documento", with: "40123456"
      fill_in "Teléfono", with: "999888777"
      click_button "Crear cliente"
    end

    # El modal cierra y el cliente queda autoseleccionado (strip visible).
    expect(page).to have_no_css("dialog.modal[open]", wait: MODAL_WAIT)
    expect(page).to have_content("Cliente Nuevo SAC")
    expect(page).to have_content("DNI 40123456")

    # El hidden sale[client_id] quedó seteado → la venta ya puede enviarse.
    hidden = find("input[name='sale[client_id]']", visible: :all)
    expect(hidden.value).to eq(Client.find_by(full_name: "Cliente Nuevo SAC").id.to_s)
  end
end
