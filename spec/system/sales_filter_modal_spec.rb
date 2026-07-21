require 'rails_helper'

RSpec.describe 'Sales filter modal', type: :system, js: true do
  let(:admin) { create(:user, :administrador) }

  before do
    allow_any_instance_of(ApplicationController)
      .to receive(:current_user).and_return(admin)
  end

  context 'on a small viewport' do
    before do
      page.driver.browser.manage.window.resize_to(375, 800)
    end

    it 'opens a dialog with filter fields when Filtros is tapped' do
      visit sales_path
      wait_until_js_booted

      expect(page).to have_link('Filtros', href: filters_sales_path)

      click_link 'Filtros'

      expect(page).to have_css('dialog[open]', visible: true)
      within('dialog[open]') do
        expect(page).to have_content('Filtros')
      end
    end
  end
end
