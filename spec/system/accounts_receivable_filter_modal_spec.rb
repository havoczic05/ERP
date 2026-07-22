require 'rails_helper'

RSpec.describe 'AccountsReceivable filter modal', type: :system, js: true do
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

    it 'opens a dialog with the due within and status filters' do
      visit accounts_receivable_path
      wait_until_js_booted

      click_link 'Filtros'

      expect(page).to have_css('dialog[open]', visible: true)
      within('dialog[open]') do
        expect(page).to have_select('Vence en', with_options: [ 'Próximos 5 días' ])
        expect(page).to have_select('Estado', with_options: [ 'Pendiente', 'Vencida' ])
      end
    end

    it 'applies the due within filter from the modal' do
      near_sale = create(:sale, :venta, :with_items)
      create(:installment, sale: near_sale, status: 'pendiente', due_date: 3.days.from_now)

      far_sale = create(:sale, :venta, :with_items)
      create(:installment, sale: far_sale, status: 'pendiente', due_date: 25.days.from_now)

      visit accounts_receivable_path
      wait_until_js_booted
      click_link 'Filtros'

      within('dialog[open]') do
        select 'Próximos 5 días', from: 'Vence en'
        click_button 'Aplicar filtros'
      end

      expect(page).to have_content(near_sale.client.full_name)
      expect(page).not_to have_content(far_sale.client.full_name)
    end

    it 'closes the modal when Escape is pressed' do
      visit accounts_receivable_path
      wait_until_js_booted
      click_link 'Filtros'

      expect(page).to have_css('dialog[open]')
      find('dialog').send_keys(:escape)
      expect(page).not_to have_css('dialog[open]')
    end
  end
end
