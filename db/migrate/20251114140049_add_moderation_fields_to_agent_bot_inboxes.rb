class AddModerationFieldsToAgentBotInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :agent_bot_inboxes, :moderation_enabled, :boolean, default: false, null: false
    add_column :agent_bot_inboxes, :explicit_words_filter, :jsonb, default: [], null: false
    add_column :agent_bot_inboxes, :sentiment_analysis_enabled, :boolean, default: false, null: false
    add_column :agent_bot_inboxes, :auto_approve_responses, :boolean, default: false, null: false

    add_index :agent_bot_inboxes, :moderation_enabled
    add_index :agent_bot_inboxes, :explicit_words_filter, using: :gin
  end
end

