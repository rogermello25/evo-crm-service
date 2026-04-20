class CreateInactivityActionExecutions < ActiveRecord::Migration[7.1]
  def change
    create_table :inactivity_action_executions, id: :uuid do |t|
      t.uuid :conversation_id, null: false
      t.uuid :agent_bot_id, null: false
      t.integer :action_index, null: false
      t.datetime :executed_at, null: false
      t.jsonb :action_config, default: {}
      t.string :action_type # 'interact' or 'finalize'
      t.text :message_sent # Mensagem que foi enviada (se interact)

      t.timestamps
    end

    add_index :inactivity_action_executions, :conversation_id
    add_index :inactivity_action_executions, :agent_bot_id
    add_index :inactivity_action_executions, [:conversation_id, :action_index], unique: true, name: 'index_inactivity_executions_on_conv_and_action'
    add_index :inactivity_action_executions, :executed_at
  end
end
