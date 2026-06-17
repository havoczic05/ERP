class CreateCompanySettings < ActiveRecord::Migration[8.1]
  def change
    create_table :company_settings do |t|
      t.string :razon_social, null: false
      t.string :ruc, null: false
      t.string :direccion
      t.string :telefono

      t.timestamps
    end
  end
end
