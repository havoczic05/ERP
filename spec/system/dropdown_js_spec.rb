require "rails_helper"

# JS system specs for the kebab dropdown menu (dropdown_controller.js).
#
# Driver: headless_chrome (js: true). Skips when Chrome is absent.
# Exercises the Stimulus controller: toggle open/close, outside click,
# Escape key, and aria-expanded attribute.
#
# Authentication: real UI login via system_login_as.

RSpec.describe "Dropdown menu (JS)", type: :system, js: true do
  let(:admin) { create(:user, :administrador) }
  let!(:client) { create(:client, :ruc_client, full_name: "Dropdown Test Client") }

  before do
    system_login_as(admin)
  end

  it "opens the dropdown menu when the kebab button is clicked" do
    visit clients_path
    wait_until_js_booted

    dropdown = first(".dropdown")
    toggle = dropdown.find(".dropdown-toggle")

    # Menu starts hidden.
    expect(dropdown).to have_css(".dropdown-menu[hidden]", visible: :hidden)
    expect(toggle["aria-expanded"]).to eq("false")

    # Click opens the menu.
    toggle.click
    expect(dropdown).to have_css(".dropdown-menu:not([hidden])", visible: :visible)
    expect(toggle["aria-expanded"]).to eq("true")
  end

  it "closes the dropdown when clicking outside" do
    visit clients_path
    wait_until_js_booted

    dropdown = first(".dropdown")
    toggle = dropdown.find(".dropdown-toggle")

    toggle.click
    expect(dropdown).to have_css(".dropdown-menu:not([hidden])", visible: :visible)

    # Click outside the dropdown to close it.
    find("h1").click
    expect(dropdown).to have_css(".dropdown-menu[hidden]", visible: :hidden)
    expect(toggle["aria-expanded"]).to eq("false")
  end

  it "closes the dropdown when Escape is pressed" do
    visit clients_path
    wait_until_js_booted

    dropdown = first(".dropdown")
    toggle = dropdown.find(".dropdown-toggle")

    toggle.click
    expect(dropdown).to have_css(".dropdown-menu:not([hidden])", visible: :visible)

    # Press Escape to close.
    page.send_keys(:escape)
    expect(dropdown).to have_css(".dropdown-menu[hidden]", visible: :hidden)
    expect(toggle["aria-expanded"]).to eq("false")
  end

  it "toggles the dropdown closed when the kebab button is clicked again" do
    visit clients_path
    wait_until_js_booted

    dropdown = first(".dropdown")
    toggle = dropdown.find(".dropdown-toggle")

    toggle.click
    expect(dropdown).to have_css(".dropdown-menu:not([hidden])", visible: :visible)

    # Second click closes it.
    toggle.click
    expect(dropdown).to have_css(".dropdown-menu[hidden]", visible: :hidden)
    expect(toggle["aria-expanded"]).to eq("false")
  end

  it "allows clicking an action inside the open dropdown" do
    visit clients_path
    wait_until_js_booted

    row = find("##{ActionView::RecordIdentifier.dom_id(client)}")
    toggle = row.find(".dropdown-toggle")

    toggle.click
    expect(row).to have_css(".dropdown-menu:not([hidden])", visible: :visible)

    # Click "Ver" inside the dropdown — should open the modal.
    within(row.find(".dropdown-menu")) do
      click_link "Ver"
    end

    expect(page).to have_css("dialog.modal[open]", wait: MODAL_WAIT)
    within("dialog.modal") do
      expect(page).to have_content("Dropdown Test Client")
    end
  end
end
