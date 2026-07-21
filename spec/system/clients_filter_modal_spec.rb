require 'rails_helper'

RSpec.describe 'Clients filter modal', type: :system, js: true do
  let(:admin) { create(:user, :administrador) }

  before do
    allow_any_instance_of(ApplicationController)
      .to receive(:current_user).and_return(admin)
  end

  context 'on a small viewport' do
    before do
      page.driver.browser.manage.window.resize_to(375, 800)
    end

    after do
      page.driver.browser.manage.window.resize_to(1400, 1400)
    end

    it 'opens a dialog with the document type filter' do
      visit clients_path
      wait_until_js_booted

      click_link 'Filtros'

      expect(page).to have_css('dialog[open]', visible: true)
      within('dialog[open]') do
        expect(page).to have_select('Tipo de documento', with_options: [ 'DNI', 'RUC' ])
      end
    end

    it 'applies the document type filter from the modal' do
      create(:client, :ruc_client, full_name: 'RUC Client')
      create(:client, :dni_client, full_name: 'DNI Client')

      visit clients_path
      wait_until_js_booted
      click_link 'Filtros'

      within('dialog[open]') do
        select 'RUC', from: 'Tipo de documento'
        click_button 'Aplicar filtros'
      end

      expect(page).to have_content('RUC Client')
      expect(page).not_to have_content('DNI Client')
    end

    it 'closes the modal when Escape is pressed' do
      visit clients_path
      wait_until_js_booted
      click_link 'Filtros'

      expect(page).to have_css('dialog[open]')
      find('dialog').send_keys(:escape)
      expect(page).not_to have_css('dialog[open]')
    end
  end
end
