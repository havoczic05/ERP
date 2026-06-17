require 'rails_helper'

# Request specs for UsersController (Slice 5 — admin-only Users management).
# Covers: CRUD, deactivation guards, role-demotion guard, self-deactivate guard, vendedor 403.
RSpec.describe 'Users', type: :request do
  let(:admin)    { create(:user, :administrador) }
  let(:vendedor) { create(:user, :vendedor) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
  end

  # ---------------------------------------------------------------------------
  # Index
  # ---------------------------------------------------------------------------
  describe 'GET /users' do
    it 'returns 200 for admin' do
      get users_path
      expect(response).to have_http_status(:ok)
    end

    it 'returns 403 for vendedor' do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(vendedor)
      get users_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # New
  # ---------------------------------------------------------------------------
  describe 'GET /users/new' do
    it 'returns 200 for admin' do
      get new_user_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # Create
  # ---------------------------------------------------------------------------
  describe 'POST /users' do
    let(:valid_params) do
      { user: { email: 'new@example.com', role: 'vendedor',
                password: 'secret123', password_confirmation: 'secret123' } }
    end

    context 'with valid params' do
      it 'creates the user and redirects' do
        expect {
          post users_path, params: valid_params
        }.to change(User, :count).by(1)
        expect(response).to have_http_status(:found)
      end
    end

    context 'with blank email' do
      it 'returns 422' do
        post users_path, params: { user: { email: '', role: 'vendedor',
                                            password: 'secret123',
                                            password_confirmation: 'secret123' } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Edit
  # ---------------------------------------------------------------------------
  describe 'GET /users/:id/edit' do
    it 'returns 200' do
      user = create(:user, :vendedor)
      get edit_user_path(user)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # Update — password handling
  # ---------------------------------------------------------------------------
  describe 'PATCH /users/:id' do
    let!(:target) { create(:user, :vendedor, password: 'oldpassword') }

    context 'when password fields are blank' do
      it 'keeps the existing password digest (old password still authenticates)' do
        digest_before = target.password_digest
        patch user_path(target), params: { user: { email: target.email, role: 'vendedor',
                                                    password: '', password_confirmation: '' } }
        expect(response).to have_http_status(:found)
        expect(target.reload.password_digest).to eq(digest_before)
        expect(target.reload.authenticate('oldpassword')).to be_truthy
      end
    end

    context 'when a new password is provided' do
      it 'updates the digest (new password authenticates)' do
        patch user_path(target), params: { user: { email: target.email, role: 'vendedor',
                                                    password: 'newpassword',
                                                    password_confirmation: 'newpassword' } }
        expect(response).to have_http_status(:found)
        expect(target.reload.authenticate('newpassword')).to be_truthy
        expect(target.reload.authenticate('oldpassword')).to be_falsey
      end
    end

    context 'with invalid role (blank)' do
      it 'returns 422' do
        patch user_path(target), params: { user: { email: target.email, role: '' } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Destroy — deactivation (soft)
  # ---------------------------------------------------------------------------
  describe 'DELETE /users/:id' do
    context 'when deactivating a normal vendedor' do
      it 'sets active to false but does NOT delete the record' do
        target = create(:user, :vendedor, active: true)
        expect {
          delete user_path(target)
        }.not_to change(User, :count)
        expect(response).to have_http_status(:found)
        expect(target.reload.active).to be false
      end
    end

    # Guard: cannot deactivate the last active administrador
    # current_user is an inactive admin (passes policy check) so the self-guard does not fire;
    # target is the only ACTIVE admin in the DB.
    context 'when admin is the only active administrador' do
      it 'redirects to users_path with a friendly alert and leaves the user active' do
        inactive_admin = create(:user, :administrador, active: false)
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(inactive_admin)
        # admin is the ONLY active administrador in the DB
        delete user_path(admin)
        expect(response).to redirect_to(users_path)
        follow_redirect!
        expect(response.body).to include('Cannot deactivate the last active administrator')
        expect(admin.reload.active).to be true
      end
    end

    # Guard: cannot deactivate yourself
    context 'when trying to deactivate yourself' do
      it 'redirects to users_path when current_user == target (even if another admin exists)' do
        _second_admin = create(:user, :administrador, active: true)
        delete user_path(admin)
        expect(response).to redirect_to(users_path)
        follow_redirect!
        expect(response.body).to include('You cannot deactivate your own account')
        expect(admin.reload.active).to be true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Update guard — cannot demote the last active administrador
  # ---------------------------------------------------------------------------
  describe 'PATCH /users/:id — last-admin demotion guard' do
    context 'when admin is the only active administrador' do
      it 'returns 422 and leaves the role unchanged' do
        patch user_path(admin), params: { user: { email: admin.email, role: 'vendedor',
                                                   password: '', password_confirmation: '' } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(admin.reload.role).to eq('administrador')
      end
    end
  end
end
