class CreateSaleItems < ActiveRecord::Migration[8.1]
  def change
    create_table :sale_items do |t|
      t.references :sale, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.decimal :unit_price_usd, precision: 10, scale: 2, null: false
      t.decimal :line_total_usd, precision: 10, scale: 2, null: false

      t.timestamps
    end

    # DB-level guard: quantity must always be a positive integer.
    execute "ALTER TABLE sale_items ADD CONSTRAINT check_quantity_positive CHECK (quantity > 0)"
  end
end
