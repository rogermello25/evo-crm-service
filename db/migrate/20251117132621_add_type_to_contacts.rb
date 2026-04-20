class AddTypeToContacts < ActiveRecord::Migration[7.1]
  def up
    # Criar tipo ENUM no PostgreSQL
    execute <<-SQL
      CREATE TYPE contact_type_enum AS ENUM ('person', 'company');
    SQL
    
    # Adicionar coluna com ENUM
    add_column :contacts, :type, :contact_type_enum, default: 'person', null: false
    add_index :contacts, :type

    # Atualizar contatos existentes para 'person'
    Contact.where(type: nil).update_all(type: 'person')
  end

  def down
    remove_index :contacts, :type
    remove_column :contacts, :type
    
    # Remover tipo ENUM do PostgreSQL
    execute <<-SQL
      DROP TYPE IF EXISTS contact_type_enum;
    SQL
  end
end
