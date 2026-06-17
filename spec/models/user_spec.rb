require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'role attribute' do
    it 'stores and returns the administrador role' do
      user = User.new(role: 'administrador', password: 'password123')
      expect(user.role).to eq('administrador')
    end

    it 'stores and returns the vendedor role' do
      user = User.new(role: 'vendedor', password: 'password123')
      expect(user.role).to eq('vendedor')
    end

    it 'is invalid with a blank role' do
      user = User.new(role: '')
      expect(user).not_to be_valid
      expect(user.errors[:role]).to be_present
    end

    it 'is invalid with an unrecognized role' do
      user = User.new(email: 'test@example.com', role: 'superadmin', password: 'password123')
      expect(user).not_to be_valid
    end

    it 'is valid with role administrador and an email' do
      user = User.new(email: 'admin@example.com', role: 'administrador', password: 'password123')
      expect(user).to be_valid
    end

    it 'is valid with role vendedor and an email' do
      user = User.new(email: 'vendor@example.com', role: 'vendedor', password: 'password123')
      expect(user).to be_valid
    end
  end

  describe 'password' do
    it 'is invalid without a password on create' do
      user = User.new(email: 'test@example.com', role: 'administrador')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it 'authenticates with correct password' do
      user = create(:user, password: 'correct_pw')
      expect(user.authenticate('correct_pw')).to eq(user)
    end

    it 'returns false when authenticating with wrong password' do
      user = create(:user, password: 'correct_pw')
      expect(user.authenticate('wrong_pw')).to be(false)
    end
  end

  describe '#admin?' do
    it 'returns true for administrador role' do
      user = User.new(role: 'administrador')
      expect(user.admin?).to be(true)
    end

    it 'returns false for vendedor role' do
      user = User.new(role: 'vendedor')
      expect(user.admin?).to be(false)
    end
  end

  describe '#vendedor?' do
    it 'returns true for vendedor role' do
      user = User.new(role: 'vendedor')
      expect(user.vendedor?).to be(true)
    end

    it 'returns false for administrador role' do
      user = User.new(role: 'administrador')
      expect(user.vendedor?).to be(false)
    end
  end
end
