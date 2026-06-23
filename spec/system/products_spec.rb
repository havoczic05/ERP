require 'rails_helper'

# System specs for Products CRUD views (RF-PM-1..6, Phase P3).
# Driver: rack_test — no Chrome/Chromium available in this environment.
# Turbo Frame JS swap is NOT tested (W-3 gap). Assertions on rendered HTML only.
RSpec.describe 'Products', type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:admin)    { create(:user, :administrador) }
  let(:vendedor) { create(:user, :vendedor) }
  let!(:warehouse) { create(:warehouse, name: 'Main Depot') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
  end

  # ---------------------------------------------------------------------------
  # Index — list rendering (RF-PM-5)
  # ---------------------------------------------------------------------------
  describe 'index page' do
    it 'shows the product list' do
      create(:product, name: 'Visible Widget', warehouse: warehouse)
      visit products_path
      expect(page).to have_content('Visible Widget')
    end

    it 'shows a link to create a new product' do
      visit products_path
      expect(page).to have_link('Nuevo producto', href: new_product_path)
    end

    it 'shows a no-results message when no kept products match' do
      visit products_path(q: 'ZZZNOMATCH')
      expect(page).to have_content('No se encontraron productos')
    end

    it 'shows only kept products' do
      create(:product, name: 'Kept One', warehouse: warehouse)
      create(:product, name: 'Discarded One', warehouse: warehouse, discarded_at: Time.current)
      visit products_path
      expect(page).to have_content('Kept One')
      expect(page).not_to have_content('Discarded One')
    end
  end

  # ---------------------------------------------------------------------------
  # Index search (RF-PM-5)
  # ---------------------------------------------------------------------------
  describe 'search form' do
    let!(:widget) { create(:product, name: 'Widget A', sku: 'WGT-100', warehouse: warehouse) }
    let!(:gadget) { create(:product, name: 'Gadget B', sku: 'GDT-200', warehouse: warehouse) }

    it 'filters results when q param is submitted' do
      visit products_path(q: 'Widget')
      expect(page).to have_content('Widget A')
      expect(page).not_to have_content('Gadget B')
    end
  end

  # ---------------------------------------------------------------------------
  # Index warehouse filter (RF-PM-5)
  # ---------------------------------------------------------------------------
  describe 'warehouse filter' do
    let(:warehouse2) { create(:warehouse, name: 'Second Depot') }
    let!(:prod_w1) { create(:product, name: 'W1 Item', warehouse: warehouse) }
    let!(:prod_w2) { create(:product, name: 'W2 Item', warehouse: warehouse2) }

    it 'renders a warehouse filter select' do
      visit products_path
      expect(page).to have_select('warehouse_id')
    end

    it 'filters results by warehouse_id param' do
      visit products_path(warehouse_id: warehouse.id)
      expect(page).to have_content('W1 Item')
      expect(page).not_to have_content('W2 Item')
    end
  end

  # ---------------------------------------------------------------------------
  # Create (RF-PM-1, RF-PM-3 — stock editable on new form)
  # ---------------------------------------------------------------------------
  describe 'creating a new product' do
    context 'with valid params' do
      it 'creates the product and shows it' do
        visit new_product_path
        fill_in 'SKU', with: 'NEW-001'
        fill_in 'Nombre', with: 'Brand New Item'
        fill_in 'Marca', with: 'ACME'
        select warehouse.name, from: 'Almacén'
        fill_in 'Stock', with: '5'
        fill_in 'Precio base USD', with: '9.99'
        click_button 'Crear producto'

        expect(page).to have_content('Brand New Item')
        expect(Product.kept.find_by(sku: 'NEW-001')).not_to be_nil
      end
    end

    context 'stock field is editable on new form (RF-PM-3)' do
      it 'renders a writable stock input' do
        visit new_product_path
        expect(page).to have_field('Stock')
      end
    end

    context 'with blank name' do
      it 'shows validation error' do
        visit new_product_path
        fill_in 'Nombre', with: ''
        fill_in 'SKU', with: 'ERR-001'
        fill_in 'Marca', with: 'X'
        select warehouse.name, from: 'Almacén'
        fill_in 'Precio base USD', with: '1.00'
        click_button 'Crear producto'

        expect(page).to have_content("no puede estar en blanco")
        expect(page).to have_button('Crear producto')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Edit (RF-PM-3 — stock read-only on edit form)
  # ---------------------------------------------------------------------------
  describe 'editing a product' do
    let!(:product) { create(:product, name: 'Old Name', stock: 10, warehouse: warehouse) }

    it 'pre-fills the form with existing data' do
      visit edit_product_path(product)
      expect(page).to have_field('Nombre', with: 'Old Name')
    end

    it 'renders stock as plain text, NOT a writable input (RF-PM-3)' do
      visit edit_product_path(product)
      # stock field must NOT be present as an input on edit
      expect(page).to have_no_field('Stock')
      # The stock value should appear as text
      expect(page).to have_content('10')
    end

    it 'updates the product and reflects new name' do
      visit edit_product_path(product)
      fill_in 'Nombre', with: 'Updated Name'
      click_button 'Actualizar producto'

      expect(page).to have_content('Updated Name')
    end
  end

  # ---------------------------------------------------------------------------
  # Delete — soft-delete + guard (RF-PM-4)
  # ---------------------------------------------------------------------------
  describe 'deleting a product' do
    context 'when product has no sale_items' do
      it 'archives the product and removes it from index' do
        product = create(:product, name: 'To Archive', warehouse: warehouse)
        visit products_path

        within("#product_#{product.id}") do
          click_button 'Eliminar'
        end

        expect(page).to have_current_path(products_path)
        expect(page).not_to have_content('To Archive')
        expect(product.reload.discarded_at).not_to be_nil
      end
    end

    context 'when product has sale_items (guard blocks)' do
      it 'shows the guard alert and product is still kept' do
        product = create(:product, name: 'Guarded Item', warehouse: warehouse)
        create(:sale_item, product: product)

        visit product_path(product)
        click_button 'Eliminar'

        expect(page).to have_content('No se puede eliminar este producto porque tiene ítems de venta asociados.')
        expect(product.reload.discarded_at).to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Vendedor: read-only (view + search only; no create/edit/delete)
  # ---------------------------------------------------------------------------
  describe 'vendedor read-only actions' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
    end

    it 'shows only "Ver" and hides "Nuevo producto"' do
      create(:product, name: 'Read Only Widget', warehouse: warehouse)
      visit products_path

      within('table tbody') do
        expect(page).to have_link('Ver')
        expect(page).not_to have_link('Editar')
        expect(page).not_to have_button('Eliminar')
      end
      expect(page).not_to have_link('Nuevo producto')
    end
  end
end
