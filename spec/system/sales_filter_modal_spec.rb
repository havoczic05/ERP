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

    after do
      page.driver.browser.manage.window.resize_to(1400, 1400)
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

    it 'applies filters from the modal and preserves the search term' do
      acme = create(:client, :ruc_client, full_name: 'ACME Corp')
      create(:sale, :venta, client: acme, status: 'confirmada',
                           created_at: Time.current, correlative: 'VTA-00001')
      create(:sale, client: acme, status: 'confirmada',
                    created_at: 1.week.ago, correlative: 'COT-00001')

      visit sales_path(q: 'ACME')
      wait_until_js_booted
      click_link 'Filtros'

      within('dialog[open]') do
        select 'Hoy', from: 'Fecha'
        select 'Venta', from: 'Tipo'
        select 'Confirmada', from: 'Estado'
        click_button 'Aplicar filtros'
      end

      expect(page).to have_current_path('/sales', ignore_query: true)

      expect(page).to have_content('VTA-00001')
      expect(page).not_to have_content('COT-00001')

      query = URI.parse(page.current_url).query
      expect(query).to include('q=ACME')
      expect(query).to include('date_range=today')
      expect(query).to include('document_type=venta')
      expect(query).to include('status=confirmada')
    end
  end
end
