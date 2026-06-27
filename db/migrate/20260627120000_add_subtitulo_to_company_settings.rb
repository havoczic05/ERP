class AddSubtituloToCompanySettings < ActiveRecord::Migration[8.1]
  def change
    add_column :company_settings, :subtitulo, :string
  end
end
