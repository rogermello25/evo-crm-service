class CreateContactCompanies < ActiveRecord::Migration[7.1]
  def change
    create_table :contact_companies, id: :uuid do |t|
      t.uuid :contact_id, null: false
      t.uuid :company_id, null: false

      t.timestamps
      t.datetime :deleted_at
    end
    
    # Foreign keys
    add_foreign_key :contact_companies, :contacts, column: :contact_id
    add_foreign_key :contact_companies, :contacts, column: :company_id
    # Índices para performance e unicidade
    add_index :contact_companies, [:contact_id, :company_id], unique: true
    add_index :contact_companies, [:company_id, :contact_id]
    add_index :contact_companies, :deleted_at
  end
end
