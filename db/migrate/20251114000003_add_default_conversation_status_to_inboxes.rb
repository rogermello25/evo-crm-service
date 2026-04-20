class AddDefaultConversationStatusToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :default_conversation_status, :string, default: nil, null: true
    add_index :inboxes, :default_conversation_status
  end
end

