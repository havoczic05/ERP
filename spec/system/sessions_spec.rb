require 'rails_helper'

# System spec for the login/logout flow.
# Driver: rack_test (no Chrome/Chromium in WSL2 environment).
# rack_test CAN submit forms and follow redirects — full end-to-end for login/logout.

RSpec.describe 'Sessions', type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:user) { create(:user, :administrador, email: 'admin@example.com') }

  # ---------------------------------------------------------------------------
  # Login flow
  # ---------------------------------------------------------------------------
  describe 'login' do
    it 'authenticates a valid user and lands on root' do
      user # ensure user is created

      visit login_path

      fill_in 'Email', with: 'admin@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Log in'

      expect(page).to have_current_path(root_path)
    end

    it 'shows an error for wrong credentials' do
      user

      visit login_path

      fill_in 'Email', with: 'admin@example.com'
      fill_in 'Password', with: 'wrongpassword'
      click_button 'Log in'

      expect(page).to have_content('Invalid email or password')
      expect(page).to have_current_path(session_path)
    end
  end

  # ---------------------------------------------------------------------------
  # Logout flow
  # ---------------------------------------------------------------------------
  describe 'logout' do
    it 'clears the session and redirects to login' do
      user

      # Log in via form
      visit login_path
      fill_in 'Email', with: 'admin@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Log in'

      expect(page).to have_current_path(root_path)

      # Log out via DELETE request (rack_test driver supports this directly).
      # The nav logout button is wired in Slice 6 (layout nav); this exercises
      # the destroy action end-to-end without requiring the layout button.
      page.driver.submit :delete, logout_path, {}

      expect(page).to have_current_path(login_path)
    end
  end
end
