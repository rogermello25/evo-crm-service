class MakeAttachmentPolymorphic < ActiveRecord::Migration[7.1]
  def up
    # Adicionar colunas polimórficas
    add_column :attachments, :attachable_type, :string
    add_column :attachments, :attachable_id, :uuid

    # Migrar dados existentes (Message -> attachable)
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE attachments
          SET attachable_type = 'Message',
              attachable_id = message_id
        SQL
      end
    end

    # Adicionar índice polimórfico
    add_index :attachments, [:attachable_type, :attachable_id]

    # Remover coluna antiga e índice antigo
    remove_index :attachments, :message_id if index_exists?(:attachments, :message_id)
    remove_column :attachments, :message_id
  end

  def down
    # Reverter mudanças
    add_column :attachments, :message_id, :uuid

    reversible do |dir|
      dir.down do
        execute <<-SQL
          UPDATE attachments
          SET message_id = attachable_id
          WHERE attachable_type = 'Message'
        SQL
      end
    end

    add_index :attachments, :message_id
    remove_index :attachments, [:attachable_type, :attachable_id]
    remove_column :attachments, :attachable_type
    remove_column :attachments, :attachable_id
  end
end
