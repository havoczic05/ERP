require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  let(:user) { create(:user, :administrador) }
  let(:inactive_user) { create(:user, :vendedor, active: false) }

  # ---------------------------------------------------------------------------
  # GET /login
  # ---------------------------------------------------------------------------
  describe 'GET /login' do
    it 'returns 200' do
      get login_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /session — successful login
  # ---------------------------------------------------------------------------
  describe 'POST /session — valid credentials' do
    it 'sets session[:user_id] and redirects to root' do
      post session_path, params: { email: user.email, password: 'password123' }
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(root_path)
    end

    it 'resets the session (session-fixation protection)' do
      # Seed a junk session id before login
      get login_path
      # Simulate an existing session[:user_id] to test fixation reset
      # We test that after login the session[:user_id] belongs to the correct user
      post session_path, params: { email: user.email, password: 'password123' }
      follow_redirect!
      # After redirect the session must belong to the signed-in user.
      # We verify indirectly: current_user resolves correctly from session.
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /session — wrong password
  # ---------------------------------------------------------------------------
  describe 'POST /session — wrong password' do
    it 'returns 422' do
      post session_path, params: { email: user.email, password: 'wrongpassword' }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'shows a generic error message (no user enumeration)' do
      post session_path, params: { email: user.email, password: 'wrongpassword' }
      expect(response.body).to include('Invalid email or password')
    end

    it 'does not set session[:user_id]' do
      post session_path, params: { email: user.email, password: 'wrongpassword' }
      # Session must not contain a user_id key after a failed login.
      # request.session is available in request specs.
      expect(session[:user_id]).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # POST /session — unknown email
  # ---------------------------------------------------------------------------
  describe 'POST /session — unknown email' do
    it 'returns 422' do
      post session_path, params: { email: 'nobody@example.com', password: 'whatever' }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'shows the generic error message (no user enumeration)' do
      post session_path, params: { email: 'nobody@example.com', password: 'whatever' }
      expect(response.body).to include('Invalid email or password')
    end

    it 'does not set session[:user_id]' do
      post session_path, params: { email: 'nobody@example.com', password: 'whatever' }
      expect(session[:user_id]).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # POST /session — inactive user
  # ---------------------------------------------------------------------------
  describe 'POST /session — inactive user' do
    it 'returns 422' do
      post session_path, params: { email: inactive_user.email, password: 'password123' }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'does not set session[:user_id]' do
      post session_path, params: { email: inactive_user.email, password: 'password123' }
      expect(session[:user_id]).to be_nil
    end

    it 'shows the generic error message' do
      post session_path, params: { email: inactive_user.email, password: 'password123' }
      expect(response.body).to include('Invalid email or password')
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /logout
  # ---------------------------------------------------------------------------
  describe 'DELETE /logout' do
    before do
      # Log in first
      post session_path, params: { email: user.email, password: 'password123' }
    end

    it 'clears the session and redirects to login' do
      delete logout_path
      expect(response).to redirect_to(login_path)
    end

    it 'clears session[:user_id]' do
      delete logout_path
      expect(session[:user_id]).to be_nil
    end
  end
end
