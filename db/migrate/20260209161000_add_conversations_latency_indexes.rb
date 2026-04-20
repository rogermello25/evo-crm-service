class AddConversationsLatencyIndexes < ActiveRecord::Migration[7.1]
  def change
    # Speeds up latest-message scans per conversation (ORDER BY created_at DESC LIMIT 1).
    add_index :messages,
              [:conversation_id, :created_at],
              order: { created_at: :desc },
              name: 'idx_messages_conv_created_desc',
              if_not_exists: true

    # Speeds up unread incoming checks by narrowing to incoming messages first.
    add_index :messages,
              [:conversation_id, :created_at],
              order: { created_at: :desc },
              where: 'message_type = 0',
              name: 'idx_messages_conv_created_incoming_desc',
              if_not_exists: true
  end
end
