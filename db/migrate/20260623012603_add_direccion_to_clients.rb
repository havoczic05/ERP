class AddDireccionToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :direccion, :string
  end
end
