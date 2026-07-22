require 'rails_helper'

RSpec.describe 'Users', type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:admin) { create(:user, :administrador) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
  end

  describe 'index page' do
    let!(:vendedor) { create(:user, :vendedor) }

    before { visit users_path }

    it 'shows heading "Usuarios"' do
      expect(page).to have_css('h1', text: 'Usuarios')
    end

    it 'shows table headers in Spanish' do
      expect(page).to have_text('Correo electrónico')
      expect(page).to have_text('Rol')
      expect(page).to have_text('Activo')
      expect(page).to have_text('Acciones')
    end

    it 'shows user rows with humanized role' do
      expect(page).to have_text('Administrador')
      expect(page).to have_text('Vendedor')
    end

    it 'shows Sí for active users' do
      within("#user_#{admin.id}") do
        expect(page).to have_text('Sí')
      end
    end

    it 'shows "Editar" link for each user' do
      within("#user_#{admin.id}") do
        expect(page).to have_link('Editar', visible: :all)
      end
    end

    it 'shows "Desactivar" button for active users' do
      within("#user_#{vendedor.id}") do
        expect(page).to have_button('Desactivar', visible: :all)
      end
    end

    it 'shows "Nuevo usuario" link' do
      expect(page).to have_link('Nuevo usuario')
    end

    it 'does not render the FAB (circular floating button)' do
      expect(page).not_to have_css('.fab')
    end
  end

  describe 'index page — inactive user' do
    let!(:inactive_vendedor) { create(:user, :vendedor, active: false) }

    before { visit users_path }

    it 'shows No for inactive users' do
      within("#user_#{inactive_vendedor.id}") do
        expect(page).to have_text('No')
      end
    end

    it 'does not show "Desactivar" for inactive users' do
      within("#user_#{inactive_vendedor.id}") do
        expect(page).not_to have_button('Desactivar', visible: :all)
      end
    end
  end

  describe 'new user page' do
    before { visit new_user_path }

    it 'shows heading "Nuevo usuario"' do
      expect(page).to have_css('.modal__title', text: 'Nuevo usuario')
    end

    it 'shows form labels in Spanish' do
      expect(page).to have_text('Correo electrónico')
      expect(page).to have_text('Rol')
      expect(page).to have_text('Contraseña')
      expect(page).to have_text('Confirmación de contraseña')
    end

    it 'shows "Crear usuario" submit button' do
      expect(page).to have_button('Crear usuario')
    end

    it 'shows "Volver a usuarios" link' do
      expect(page).to have_link('Volver a usuarios', href: users_path)
    end

    it 'creates user and shows flash notice' do
      fill_in 'Correo electrónico', with: 'nuevo@example.com'
      select 'Administrador', from: 'Rol'
      fill_in 'Contraseña', with: 'password123'
      fill_in 'Confirmación de contraseña', with: 'password123'
      click_button 'Crear usuario'

      expect(page).to have_text('Usuario creado correctamente.')
    end
  end

  describe 'edit user page' do
    let!(:vendedor) { create(:user, :vendedor) }

    before { visit edit_user_path(vendedor) }

    it 'shows heading "Editar usuario"' do
      expect(page).to have_css('.modal__title', text: 'Editar usuario')
    end

    it 'shows "Actualizar usuario" submit button' do
      expect(page).to have_button('Actualizar usuario')
    end

    it 'shows "Volver a usuarios" link' do
      expect(page).to have_link('Volver a usuarios', href: users_path)
    end

    it 'updates user and shows flash notice' do
      fill_in 'Correo electrónico', with: 'actualizado@example.com'
      click_button 'Actualizar usuario'

      expect(page).to have_text('Usuario actualizado correctamente.')
    end
  end

  describe 'deactivate user' do
    let!(:vendedor) { create(:user, :vendedor) }

    it 'deactivates user and shows flash notice' do
      visit users_path

      within("#user_#{vendedor.id}") do
        find_button('Desactivar', visible: :all).click
      end

      expect(page).to have_text('Usuario desactivado correctamente.')
      within("#user_#{vendedor.id}") do
        expect(page).to have_text('No')
      end
    end
  end

  describe 'deactivate guard: cannot deactivate own account' do
    it 'shows alert when admin tries to deactivate themselves' do
      visit users_path

      within("#user_#{admin.id}") do
        find_button('Desactivar', visible: :all).click
      end

      expect(page).to have_text('No puede desactivar su propia cuenta.')
    end
  end

  describe 'deactivate guard: cannot deactivate last active administrator' do
    it 'shows alert when deactivating the last active admin' do
      # sole_admin is the target. admin is current_user (still active as admin).
      # Deactivate admin directly in DB so sole_admin becomes the last active admin,
      # then try to deactivate sole_admin as admin (current_user).
      # This avoids the self-deactivation guard because target != current_user.
      sole_admin = create(:user, :administrador)

      # Make admin inactive at DB level so sole_admin is now the last active admin.
      admin.update_column(:active, false)

      visit users_path

      within("#user_#{sole_admin.id}") do
        find_button('Desactivar', visible: :all).click
      end

      expect(page).to have_text('No se puede desactivar al último administrador activo.')
    end
  end
end
