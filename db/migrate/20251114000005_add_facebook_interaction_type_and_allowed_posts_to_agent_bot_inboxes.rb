class AddFacebookInteractionTypeAndAllowedPostsToAgentBotInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :agent_bot_inboxes, :facebook_interaction_type, :string, default: 'both', null: false
    add_column :agent_bot_inboxes, :facebook_allowed_post_ids, :jsonb, default: [], null: false

    add_index :agent_bot_inboxes, :facebook_interaction_type
    add_index :agent_bot_inboxes, :facebook_allowed_post_ids, using: :gin
  end
end

