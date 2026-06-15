class CreateAmortizations < ActiveRecord::Migration[8.1]
  def change
    create_table :amortizations do |t|
      t.references :installment, null: false, foreign_key: true
      t.decimal :amount_usd, precision: 10, scale: 2, null: false
      t.datetime :paid_at, null: false
      t.text :notes

      t.timestamps
    end
  end
end
