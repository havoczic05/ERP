class CreateSales < ActiveRecord::Migration[8.1]
  def change
    create_table :sales do |t|
      t.references :client, null: false, foreign_key: true
      t.references :warehouse, null: false, foreign_key: true
      t.string :document_type, null: false
      t.string :status, null: false
      t.string :correlative, null: false
      t.decimal :subtotal_usd, precision: 10, scale: 2, null: false, default: 0
      t.decimal :tax_usd, precision: 10, scale: 2, null: false, default: 0
      t.decimal :total_usd, precision: 10, scale: 2, null: false, default: 0
      t.string :billing_status, default: 'pending'
      t.jsonb :billing_response_metadata, default: {}
      t.text :notes
      t.datetime :confirmed_at
      t.datetime :discarded_at
      # Self-referential FK for cotizacion → venta conversion linkage.
      t.bigint :source_cotizacion_id

      t.timestamps
    end

    # Unique index on correlative: race-guard for concurrent correlative generation.
    add_index :sales, :correlative, unique: true
    add_index :sales, :document_type
    add_index :sales, :status

    # Self-referential FK (optional source cotizacion linkage).
    add_foreign_key :sales, :sales, column: :source_cotizacion_id
  end
end
