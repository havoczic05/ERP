class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.string :full_name, null: false
      t.string :document_type, null: false
      t.string :document_number, null: false
      t.string :phone, null: false
      t.datetime :discarded_at

      t.timestamps
    end

    # Partial unique index: only active (non-discarded) clients must have unique document_number.
    # This enforces race-condition safety at the DB layer even when model-level validation is bypassed.
    add_index :clients, :document_number, unique: true, where: "discarded_at IS NULL"
  end
end
