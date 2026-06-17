class CreateInstallments < ActiveRecord::Migration[8.1]
  def change
    create_table :installments do |t|
      t.references :sale, null: false, foreign_key: true
      t.integer :installment_number, null: false
      t.decimal :amount_usd, precision: 10, scale: 2, null: false
      t.decimal :balance_usd, precision: 10, scale: 2, null: false
      t.date :due_date, null: false
      t.string :status, null: false

      t.timestamps
    end

    # Composite unique index: prevents duplicate installment numbers per sale.
    add_index :installments, [ :sale_id, :installment_number ], unique: true
  end
end
