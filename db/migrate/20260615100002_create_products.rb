class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :sku, null: false
      t.string :name, null: false
      t.string :brand, null: false
      t.references :warehouse, null: false, foreign_key: true
      t.integer :stock, null: false, default: 0
      t.decimal :base_price_usd, precision: 10, scale: 2, null: false
      t.datetime :discarded_at

      t.timestamps
    end

    # DB-level stock safety net: stock must never go negative.
    execute "ALTER TABLE products ADD CONSTRAINT check_stock_non_negative CHECK (stock >= 0)"

    # Partial unique index: SKU must be unique among active (non-discarded) products.
    add_index :products, :sku, unique: true, where: "discarded_at IS NULL"
  end
end
