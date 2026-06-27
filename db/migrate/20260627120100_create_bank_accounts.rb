class CreateBankAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_accounts do |t|
      t.references :company_settings, null: false, foreign_key: true
      t.string :bank, null: false
      t.string :currency_label
      t.string :account_number
      t.string :interbank_number
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :bank_accounts, [ :company_settings_id, :position ]
  end
end
