# frozen_string_literal: true

class RemoveCustomRoles < ActiveRecord::Migration[7.1]
  def up
    # Drop table if it exists
    drop_table :custom_roles, if_exists: true
  end

  def down
    # Recreate table (if needed for rollback)
    create_table :custom_roles, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.jsonb :permissions, default: []
      t.timestamps
    end

    add_index :custom_roles, [:name], unique: true
  end
end

