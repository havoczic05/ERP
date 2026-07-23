require 'rails_helper'

# System specs for Clients CRUD views (Phase 6).
# Driver: rack_test (default) — no Chrome/Chromium available in this environment.
# JS-dependent behavior (Turbo Frame in-place swap without page reload) is tested
# via HTTP response content rather than browser interaction; the Turbo Frame tag
# renders in the HTML and rack_test can assert on its contents.
#
# Skipped (require real JS driver): SPA-style turbo replacement animation, streaming
# broadcasts, and any scenario that requires JS event execution.

RSpec.describe 'Clients', type: :system do
  # ---------------------------------------------------------------------------
  # Driver: rack_test (no Chrome/Chromium in this WSL environment).
  # JS-specific behaviors (Turbo Frame swap animations, streaming) are tested
  # via HTTP response content — rack_test sees the rendered HTML directly.
  # ---------------------------------------------------------------------------
  before do
    driven_by(:rack_test)
  end

  # ---------------------------------------------------------------------------
  # Sign-in stub: inject current_user so Pundit authorize passes.
  # ApplicationController#current_user= is available in test env only.
  # ---------------------------------------------------------------------------
  let(:user) { create(:user, :administrador) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  # ---------------------------------------------------------------------------
  # Index — list of kept clients
  # ---------------------------------------------------------------------------
  describe 'index page' do
    it 'shows kept clients' do
      client = create(:client, :ruc_client, full_name: 'Visible Corp')
      discarded = create(:client, :ruc_client, full_name: 'Hidden Corp').tap(&:discard)

      visit clients_path
      expect(page).to have_content('Visible Corp')
      expect(page).not_to have_content('Hidden Corp')
    end

    it 'shows a link to create a new client' do
      visit clients_path
      expect(page).to have_link('Nuevo cliente', href: new_client_path)
    end

    it 'renders the FAB (pill-shaped floating button) for create action' do
      visit clients_path
      expect(page).to have_css('.fab')
      expect(page).to have_css('.fab span', text: 'Nuevo cliente')
      expect(page).to have_no_css('.fab[aria-label]')
    end

    it 'positions the FAB on mobile/tablet and shows inline button on desktop', :js do
      driven_by(:headless_chrome)

      begin
        # Mobile (375px): FAB visible + fixed, inline button hidden
        page.driver.browser.manage.window.resize_to(375, 800)
        visit clients_path
        fab = find('.fab', visible: :all)
        expect(fab.native.style('position')).to eq('fixed')
        expect(fab.native.style('display')).not_to eq('none')
        expect(fab).to have_text('Nuevo cliente')
        expect(page).to have_no_css('.fab[aria-label]')
        inline = find('.page-head--with-action > a.btn:not(.fab)', visible: :all)
        expect(inline.native.style('display')).to eq('none')

        # Boundary: tablet 768px ≤ 1024px — still FAB visible
        page.driver.browser.manage.window.resize_to(768, 800)
        visit clients_path
        fab = find('.fab', visible: :all)
        expect(fab.native.style('display')).not_to eq('none')
        expect(fab).to have_text('Nuevo cliente')
        expect(page).to have_no_css('.fab[aria-label]')
        inline = find('.page-head--with-action > a.btn:not(.fab)', visible: :all)
        expect(inline.native.style('display')).to eq('none')

        # Desktop (1366px): inline visible, FAB hidden
        page.driver.browser.manage.window.resize_to(1366, 900)
        visit clients_path
        fab = find('.fab', visible: :all)
        expect(fab.native.style('display')).to eq('none')
        inline = find('.page-head--with-action > a.btn:not(.fab)', visible: :all)
        expect(inline.native.style('display')).not_to eq('none')
      ensure
        page.driver.browser.manage.window.resize_to(1400, 1400)
      end
    end

    it 'offers a "Limpiar" link that resets the filters' do
      visit clients_path(q: 'Acme')
      expect(page).to have_link('Limpiar', href: clients_path)
    end

    it 'shows distrito, provincia y departamento columns with their values' do
      create(:client, :ruc_client, full_name: 'Loc Corp',
                                   distrito: 'Miraflores', provincia: 'Lima', departamento: 'Lima')

      visit clients_path

      expect(page).to have_css('thead th', text: 'Distrito')
      expect(page).to have_css('thead th', text: 'Provincia')
      expect(page).to have_css('thead th', text: 'Departamento')
      expect(page).to have_content('Miraflores')
    end
  end

  # ---------------------------------------------------------------------------
  # Search filter on index
  # ---------------------------------------------------------------------------
  describe 'search on index' do
    it 'filters by document_number' do
      match    = create(:client, :ruc_client, document_number: '20000000001', full_name: 'Match Client')
      no_match = create(:client, :ruc_client, document_number: '20000000002', full_name: 'No Match Client')

      visit clients_path(q: '20000000001')
      expect(page).to have_content('Match Client')
      expect(page).not_to have_content('No Match Client')
    end

    it 'filters by full_name' do
      match    = create(:client, :ruc_client, full_name: 'Acme Corp')
      no_match = create(:client, :ruc_client, full_name: 'Other Company')

      visit clients_path(q: 'Acme')
      expect(page).to have_content('Acme Corp')
      expect(page).not_to have_content('Other Company')
    end

    it 'shows no results message when nothing matches' do
      visit clients_path(q: 'ZZZNOMATCH')
      # Table is present but has no client rows
      expect(page).not_to have_css('table tbody tr[id^="client_"]')
      # Spec requires a visible "no records found" message
      expect(page).to have_content('No se encontraron clientes.')
    end
  end

  # ---------------------------------------------------------------------------
  # Create — valid params
  # ---------------------------------------------------------------------------
  describe 'creating a new client' do
    context 'with valid params' do
      it 'creates the client and redirects to show' do
        visit new_client_path

        fill_in 'Nombre completo', with: 'Test Client SA'
        select 'Ruc', from: 'Tipo de documento'
        fill_in 'Número de documento', with: '20123456789'
        fill_in 'Teléfono', with: '987654321'
        click_button 'Crear cliente'

        expect(page).to have_content('Test Client SA')
        expect(Client.kept.find_by(document_number: '20123456789')).not_to be_nil
      end

      it 'persists distrito, provincia y departamento' do
        visit new_client_path

        fill_in 'Nombre completo', with: 'Geo Client'
        select 'Ruc', from: 'Tipo de documento'
        fill_in 'Número de documento', with: '20123456789'
        fill_in 'Teléfono', with: '987654321'
        fill_in 'Distrito', with: 'Surco'
        fill_in 'Provincia', with: 'Lima'
        fill_in 'Departamento', with: 'Lima'
        click_button 'Crear cliente'

        client = Client.kept.find_by(document_number: '20123456789')
        expect(client.distrito).to eq('Surco')
        expect(client.provincia).to eq('Lima')
        expect(client.departamento).to eq('Lima')
      end
    end

    # Inline errors via Turbo Frame:
    # With rack_test, the form is re-rendered with error messages in the HTML
    # (the Turbo Frame tag is transparent to rack_test). We assert on error content.
    context 'with invalid params (inline errors via Turbo Frame form)' do
      it 'shows validation errors without leaving the form' do
        visit new_client_path

        fill_in 'Nombre completo', with: ''
        select 'Ruc', from: 'Tipo de documento'
        fill_in 'Número de documento', with: ''
        fill_in 'Teléfono', with: ''
        click_button 'Crear cliente'

        expect(page).to have_content("no puede estar en blanco")
        # Still on new client page (form re-rendered in-frame)
        expect(page).to have_button('Crear cliente')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Show
  # ---------------------------------------------------------------------------
  describe 'show page' do
    it 'displays all client fields' do
      client = create(:client, :ruc_client, full_name: 'Show Corp', phone: '912345678')

      visit client_path(client)
      expect(page).to have_content('Show Corp')
      expect(page).to have_content(client.document_number)
      expect(page).to have_content('912345678')
    end
  end

  # ---------------------------------------------------------------------------
  # Edit / Update
  # ---------------------------------------------------------------------------
  describe 'editing a client' do
    it 'updates the client and redirects' do
      client = create(:client, :ruc_client, full_name: 'Before Update')

      visit edit_client_path(client)
      fill_in 'Nombre completo', with: 'After Update'
      click_button 'Actualizar cliente'

      expect(page).to have_content('After Update')
    end
  end

  # ---------------------------------------------------------------------------
  # Destroy — soft-delete
  # ---------------------------------------------------------------------------
  describe 'archiving a client' do
    it 'soft-deletes the client and redirects to index' do
      client = create(:client, :ruc_client, full_name: 'To Archive')

      visit clients_path
      expect(page).to have_content('To Archive')

      # Click the Archive button for this specific client row.
      # dom_id is an ActionView helper; build the CSS id manually here.
      within("#client_#{client.id}") do
        find_button('Archivar', visible: :all).click
      end

      expect(client.reload.discarded?).to be true
      expect(page).to have_current_path(clients_path)
      expect(page).not_to have_content('To Archive')
    end
  end

  # ---------------------------------------------------------------------------
  # Vendedor: read-only actions (can view + create, but not edit/archive)
  # ---------------------------------------------------------------------------
  describe 'vendedor row actions' do
    let(:user) { create(:user, :vendedor) }

    it 'shows only "Ver" (no Editar / Archivar) but keeps "Nuevo cliente"' do
      create(:client, :ruc_client, full_name: 'Read Only Co')
      visit clients_path

      within('table tbody') do
        expect(page).to have_link('Ver', visible: :all)
        expect(page).not_to have_link('Editar', visible: :all)
        expect(page).not_to have_button('Archivar', visible: :all)
      end
      expect(page).to have_link('Nuevo cliente')
    end
  end
end
