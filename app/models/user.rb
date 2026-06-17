class User < ApplicationRecord
  ROLES = %w[administrador vendedor].freeze

  has_secure_password

  scope :active, -> { where(active: true) }

  validates :email, presence: true
  validates :role, inclusion: { in: ROLES }

  def admin?
    role == "administrador"
  end

  def vendedor?
    role == "vendedor"
  end

  def self.last_active_admin?(user)
    user.admin? && active.where(role: "administrador").where.not(id: user.id).none?
  end
end
