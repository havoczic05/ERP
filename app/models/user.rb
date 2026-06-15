class User < ApplicationRecord
  ROLES = %w[administrador vendedor].freeze

  validates :email, presence: true
  validates :role, inclusion: { in: ROLES }
end
