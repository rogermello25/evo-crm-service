class CreateFacebookCommentModerations < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:facebook_comment_moderations)

    create_table :facebook_comment_moderations, id: :uuid do |t|
      t.references :conversation, null: false, foreign_key: true, type: :uuid
      t.references :message, null: false, foreign_key: true, type: :uuid
      t.string :comment_id, null: false # Facebook comment ID
      t.string :moderation_type, null: false # 'explicit_words', 'offensive_sentiment', 'response_approval'
      t.string :status, null: false, default: 'pending' # 'pending', 'approved', 'rejected'
      t.string :action_type, null: false # 'delete_comment', 'block_user', 'send_response'
      t.text :response_content # Generated response content (if applicable)
      t.text :rejection_reason # Reason for rejection
      t.references :moderated_by, null: true, foreign_key: { to_table: :users }, type: :uuid
      t.datetime :moderated_at

      t.timestamps
    end

    add_index :facebook_comment_moderations, :status unless index_exists?(:facebook_comment_moderations, :status)
    add_index :facebook_comment_moderations, :moderation_type unless index_exists?(:facebook_comment_moderations, :moderation_type)
    add_index :facebook_comment_moderations, :comment_id unless index_exists?(:facebook_comment_moderations, :comment_id)
    add_index :facebook_comment_moderations, [:status, :moderation_type] unless index_exists?(:facebook_comment_moderations, [:status, :moderation_type])
    # Note: conversation_id, message_id, and moderated_by_id indexes are automatically created by t.references
  end
end
