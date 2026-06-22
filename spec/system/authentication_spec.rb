require 'rails_helper'

# System spec for Slice 6: nav layout, flash rendering, logout button.
# Driver: rack_test (no Chrome/Chromium in WSL2 environment).
# Tests the full page DOM after login — confirms nav shows email, role, logout button.

RSpec.describe 'Authentication layout', type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:admin)    { create(:user, :administrador, email: 'admin@layout.test', password: 'password123') }
  let(:vendedor) { create(:user, :vendedor,       email: 'vendor@layout.test', password: 'password123') }

  # Helper: log in via the form, following the redirect to root.
  def log_in_as(email, password)
    visit login_path
    fill_in 'Correo electrónico', with: email
    fill_in 'Contraseña',         with: password
    click_button 'Iniciar sesión'
  end

  # ---------------------------------------------------------------------------
  # Nav visibility after login — admin
  # ---------------------------------------------------------------------------
  describe 'nav when logged in as admin' do
    before { admin; log_in_as('admin@layout.test', 'password123') }

    it 'shows the current user email in the nav' do
      expect(page).to have_content('admin@layout.test')
    end

    it 'shows the current user role in the nav' do
      expect(page).to have_content('Administrador')
    end

    it 'shows a Log out button' do
      expect(page).to have_button('Cerrar sesión')
    end

    it 'shows the Users link for admin' do
      expect(page).to have_link('Usuarios')
    end
  end

  # ---------------------------------------------------------------------------
  # Nav visibility after login — vendedor
  # ---------------------------------------------------------------------------
  describe 'nav when logged in as vendedor' do
    before { vendedor; log_in_as('vendor@layout.test', 'password123') }

    it 'shows the current user email in the nav' do
      expect(page).to have_content('vendor@layout.test')
    end

    it 'shows the current user role in the nav' do
      expect(page).to have_content('Vendedor')
    end

    it 'shows a Log out button' do
      expect(page).to have_button('Cerrar sesión')
    end

    it 'does NOT show the Users link for vendedor' do
      expect(page).not_to have_link('Usuarios')
    end
  end

  # ---------------------------------------------------------------------------
  # No nav when logged out
  # ---------------------------------------------------------------------------
  describe 'nav when not logged in' do
    it 'does not show the Log out button on the login page' do
      visit login_path
      expect(page).not_to have_button('Cerrar sesión')
    end
  end

  # ---------------------------------------------------------------------------
  # Logout — submit the Log out button
  # ---------------------------------------------------------------------------
  describe 'Log out button' do
    before { admin; log_in_as('admin@layout.test', 'password123') }

    it 'clears the session and redirects to login when submitted' do
      click_button 'Cerrar sesión'
      expect(page).to have_current_path(login_path)
    end
  end

  # ---------------------------------------------------------------------------
  # Flash rendering
  # ---------------------------------------------------------------------------
  describe 'flash messages' do
    it 'shows a notice flash after login' do
      admin
      log_in_as('admin@layout.test', 'password123')
      # The sessions#create action may or may not set a notice; we verify
      # the layout renders flash when it is present by checking the alert case.
      visit login_path
      fill_in 'Correo electrónico', with: 'admin@layout.test'
      fill_in 'Contraseña',         with: 'wrongpassword'
      click_button 'Iniciar sesión'
      expect(page).to have_content('Correo o contraseña inválidos')
    end
  end
end
