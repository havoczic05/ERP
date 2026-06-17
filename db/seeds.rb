# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Default warehouse — idempotent, safe to run in any environment.
Warehouse.find_or_create_by!(name: 'Almacén Principal') do |w|
  w.location = 'Lima, Peru'
end

# Default admin user — idempotent, safe to run in any environment.
User.find_or_create_by!(email: 'admin@erp.local') do |u|
  u.role     = 'administrador'
  u.password = ENV.fetch('SEED_ADMIN_PASSWORD', 'changeme123')
  u.active   = true
end
