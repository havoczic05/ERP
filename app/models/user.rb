class User < ApplicationRecord
  ROLES = %w[administrador vendedor].freeze

  HUMAN_ATTRS = {
    "email" => "Correo electrónico",
    "role" => "Rol",
    "password" => "Contraseña",
    "password_confirmation" => "Confirmación de contraseña"
  }.freeze
  include SpanishAttributeNames

  has_secure_password

  scope :active, -> { where(active: true) }

  validates :email, presence: { message: "no puede estar en blanco" }
  validates :role, inclusion: { in: ROLES, message: "no es válido" }

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
