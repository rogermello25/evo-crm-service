class AddCompanyFieldsToContacts < ActiveRecord::Migration[7.1]
  def change
    add_column :contacts, :tax_id, :string, limit: 14
    add_column :contacts, :website, :string
    add_column :contacts, :industry, :string
    
    # Índice para tax_id (CNPJ/CPF)
    add_index :contacts, [:tax_id], unique: true, where: "tax_id IS NOT NULL"
  end
end
