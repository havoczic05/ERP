require 'rails_helper'

# TDD spec for UserPolicy (auth-module slice 4)
# administrador: all 7 actions allowed
# vendedor: all 7 actions denied
# nil user: all 7 actions denied
RSpec.describe UserPolicy, type: :policy do
  let(:administrador) { build(:user, :administrador) }
  let(:vendedor)      { build(:user, :vendedor) }
  let(:record)        { build(:user, :vendedor) }

  subject { described_class }

  ADMIN_ONLY_ACTIONS = %i[index? show? new? create? edit? update? destroy?].freeze

  # -----------------------------------------------------------------------
  # Administrador: all actions allowed
  # -----------------------------------------------------------------------
  shared_examples 'allows all user actions' do |role_name|
    let(:user) { send(role_name) }

    ADMIN_ONLY_ACTIONS.each do |action|
      it "grants #{role_name} #{action}" do
        expect(subject.new(user, record).public_send(action)).to be true
      end
    end
  end

  include_examples 'allows all user actions', :administrador

  # -----------------------------------------------------------------------
  # Vendedor: all actions denied
  # -----------------------------------------------------------------------
  describe 'vendedor' do
    let(:user) { vendedor }

    ADMIN_ONLY_ACTIONS.each do |action|
      it "denies vendedor #{action}" do
        expect(subject.new(user, record).public_send(action)).to be false
      end
    end
  end

  # -----------------------------------------------------------------------
  # Nil user: all actions denied
  # -----------------------------------------------------------------------
  describe 'nil user' do
    let(:user) { nil }

    ADMIN_ONLY_ACTIONS.each do |action|
      it "denies nil user #{action}" do
        expect(subject.new(user, record).public_send(action)).to be false
      end
    end
  end
end
