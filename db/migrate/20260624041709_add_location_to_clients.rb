class AddLocationToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :distrito, :string
    add_column :clients, :provincia, :string
    add_column :clients, :departamento, :string
  end
end
