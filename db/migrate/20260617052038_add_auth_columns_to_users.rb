class AddAuthColumnsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_digest, :string
    add_column :users, :active, :boolean, null: false, default: true
  end
end
