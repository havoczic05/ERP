class RemoveNotesFromAmortizations < ActiveRecord::Migration[8.1]
  def change
    remove_column :amortizations, :notes, :text
  end
end
