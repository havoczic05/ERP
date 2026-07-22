require 'rails_helper'

# System specs for Warehouses CRUD views (Phase W3).
# Driver: rack_test — no Chrome/Chromium available in this environment.
# Turbo Frame JS swap is NOT tested (W-3 gap). Assertions are on rendered HTML only.
RSpec.describe 'Warehouses', type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:admin)    { create(:user, :administrador) }
  let(:vendedor) { create(:user, :vendedor) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
  end

  # ---------------------------------------------------------------------------
  # Index — list rendering
  # ---------------------------------------------------------------------------
  describe 'index page' do
    it 'shows the warehouse list' do
      create(:warehouse, name: 'Central Depot')
      visit warehouses_path
      expect(page).to have_content('Central Depot')
    end

    it 'shows a link to create a new warehouse' do
      visit warehouses_path
      expect(page).to have_link('Nuevo almacén', href: new_warehouse_path)
    end

    it 'shows a no-results message when no warehouses exist' do
      visit warehouses_path
      expect(page).to have_content('No se encontraron almacenes.')
    end

    it 'does not render the FAB (circular floating button)' do
      visit warehouses_path
      expect(page).not_to have_css('.fab')
    end
  end

  # ---------------------------------------------------------------------------
  # Create — valid and invalid
  # ---------------------------------------------------------------------------
  describe 'creating a new warehouse' do
    context 'with valid params' do
      it 'creates the warehouse and shows it in the list' do
        visit new_warehouse_path
        fill_in 'Nombre', with: 'New Storage'
        fill_in 'Ubicación', with: 'Callao'
        click_button 'Crear almacén'

        expect(page).to have_content('New Storage')
        expect(Warehouse.find_by(name: 'New Storage')).not_to be_nil
      end
    end

    context 'with blank name (inline errors via Turbo Frame form)' do
      it 'shows validation errors without leaving the form' do
        visit new_warehouse_path
        fill_in 'Nombre', with: ''
        click_button 'Crear almacén'

        expect(page).to have_content("no puede estar en blanco")
        expect(page).to have_button('Crear almacén')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Edit / Update
  # ---------------------------------------------------------------------------
  describe 'editing a warehouse' do
    it 'pre-fills the form with existing data' do
      wh = create(:warehouse, name: 'Old Name', location: 'Lima')
      visit edit_warehouse_path(wh)
      expect(page).to have_field('Nombre', with: 'Old Name')
    end

    it 'updates the warehouse and reflects the new name' do
      wh = create(:warehouse, name: 'Before Update')
      visit edit_warehouse_path(wh)
      fill_in 'Nombre', with: 'After Update'
      click_button 'Actualizar almacén'

      expect(page).to have_content('After Update')
    end

    it 'shows validation errors when name is blank' do
      wh = create(:warehouse, name: 'Valid Name')
      visit edit_warehouse_path(wh)
      fill_in 'Nombre', with: ''
      click_button 'Actualizar almacén'

      expect(page).to have_content("no puede estar en blanco")
      expect(page).to have_button('Actualizar almacén')
    end
  end

  # ---------------------------------------------------------------------------
  # Delete with dependents — flash alert, row still in index (RF-WM-2)
  # W-3 note: Turbo Frame swap is NOT tested with rack_test; we assert the
  # redirect + re-rendered show page with flash alert.
  # ---------------------------------------------------------------------------
  describe 'deleting a warehouse' do
    context 'when warehouse has no dependents' do
      it 'deletes and row is gone from index' do
        wh = create(:warehouse, name: 'To Delete')
        visit warehouses_path

        within("#warehouse_#{wh.id}") do
          find_button('Eliminar', visible: :all).click
        end

        expect(page).to have_current_path(warehouses_path)
        expect(page).not_to have_content('To Delete')
        expect(Warehouse.find_by(id: wh.id)).to be_nil
      end
    end

    context 'when warehouse has a product (guard blocks delete)' do
      it 'shows the guard alert and warehouse is still present' do
        wh = create(:warehouse, name: 'Guarded Depot')
        create(:product, warehouse: wh)

        visit warehouses_path
        within("#warehouse_#{wh.id}") { find_button('Eliminar', visible: :all).click }

        expect(page).to have_content('No se puede eliminar este almacén porque tiene productos o ventas asociadas.')
        expect(page).to have_current_path(warehouses_path)
        expect(Warehouse.find_by(id: wh.id)).not_to be_nil
      end
    end
  end
end
