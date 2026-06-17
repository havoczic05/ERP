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
      expect(page).to have_link('New Warehouse', href: new_warehouse_path)
    end

    it 'shows a no-results message when no warehouses exist' do
      visit warehouses_path
      expect(page).to have_content('No warehouses found.')
    end
  end

  # ---------------------------------------------------------------------------
  # Create — valid and invalid
  # ---------------------------------------------------------------------------
  describe 'creating a new warehouse' do
    context 'with valid params' do
      it 'creates the warehouse and shows it in the list' do
        visit new_warehouse_path
        fill_in 'Name', with: 'New Storage'
        fill_in 'Location', with: 'Callao'
        click_button 'Create Warehouse'

        expect(page).to have_content('New Storage')
        expect(Warehouse.find_by(name: 'New Storage')).not_to be_nil
      end
    end

    context 'with blank name (inline errors via Turbo Frame form)' do
      it 'shows validation errors without leaving the form' do
        visit new_warehouse_path
        fill_in 'Name', with: ''
        click_button 'Create Warehouse'

        expect(page).to have_content("can't be blank")
        expect(page).to have_button('Create Warehouse')
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
      expect(page).to have_field('Name', with: 'Old Name')
    end

    it 'updates the warehouse and reflects the new name' do
      wh = create(:warehouse, name: 'Before Update')
      visit edit_warehouse_path(wh)
      fill_in 'Name', with: 'After Update'
      click_button 'Update Warehouse'

      expect(page).to have_content('After Update')
    end

    it 'shows validation errors when name is blank' do
      wh = create(:warehouse, name: 'Valid Name')
      visit edit_warehouse_path(wh)
      fill_in 'Name', with: ''
      click_button 'Update Warehouse'

      expect(page).to have_content("can't be blank")
      expect(page).to have_button('Update Warehouse')
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
          click_button 'Delete'
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

        visit warehouse_path(wh)
        click_button 'Delete'

        expect(page).to have_content('cannot be deleted')
        expect(Warehouse.find_by(id: wh.id)).not_to be_nil
      end
    end
  end
end
