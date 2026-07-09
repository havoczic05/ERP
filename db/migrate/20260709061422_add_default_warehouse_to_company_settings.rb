class AddDefaultWarehouseToCompanySettings < ActiveRecord::Migration[8.1]
  def change
    add_column :company_settings, :default_warehouse_id, :bigint
    add_foreign_key :company_settings, :warehouses, column: :default_warehouse_id, on_delete: :nullify
  end
end
