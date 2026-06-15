class CreateCreditNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_notes do |t|
      # index: false because we add a unique index manually below.
      t.references :sale, null: false, foreign_key: true, index: false
      t.decimal :total_usd, precision: 10, scale: 2, null: false
      t.datetime :issued_at, null: false
      t.text :notes

      t.timestamps
    end

    # Unique index on sale_id: enforces one credit note per sale invariant.
    add_index :credit_notes, :sale_id, unique: true
  end
end
