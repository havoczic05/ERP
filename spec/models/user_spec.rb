require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'role attribute' do
    it 'stores and returns the administrador role' do
      user = User.new(role: 'administrador')
      expect(user.role).to eq('administrador')
    end

    it 'stores and returns the vendedor role' do
      user = User.new(role: 'vendedor')
      expect(user.role).to eq('vendedor')
    end

    it 'is invalid with a blank role' do
      user = User.new(role: '')
      expect(user).not_to be_valid
      expect(user.errors[:role]).to be_present
    end

    it 'is invalid with an unrecognized role' do
      user = User.new(email: 'test@example.com', role: 'superadmin')
      expect(user).not_to be_valid
    end

    it 'is valid with role administrador and an email' do
      user = User.new(email: 'admin@example.com', role: 'administrador')
      expect(user).to be_valid
    end

    it 'is valid with role vendedor and an email' do
      user = User.new(email: 'vendor@example.com', role: 'vendedor')
      expect(user).to be_valid
    end
  end
end
