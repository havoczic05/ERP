require 'rails_helper'

# Spec for seed idempotency: running the admin seed block twice must yield
# exactly one User with email admin@erp.local and role administrador.
RSpec.describe 'Seeds — admin user', type: :model do
  def run_admin_seed
    User.find_or_create_by!(email: 'admin@erp.local') do |u|
      u.role     = 'administrador'
      u.password = ENV.fetch('SEED_ADMIN_PASSWORD', 'changeme123')
      u.active   = true
    end
  end

  it 'creates exactly one admin@erp.local on first run' do
    expect { run_admin_seed }.to change(User, :count).by(1)
    expect(User.find_by(email: 'admin@erp.local').role).to eq('administrador')
  end

  it 'is idempotent — running twice yields exactly one record' do
    run_admin_seed
    expect { run_admin_seed }.not_to change(User, :count)
  end

  it 'creates the user with active: true' do
    run_admin_seed
    expect(User.find_by(email: 'admin@erp.local').active).to be(true)
  end

  it 'authenticates with the default seed password' do
    run_admin_seed
    user = User.find_by(email: 'admin@erp.local')
    expect(user.authenticate('changeme123')).to be_truthy
  end
end
