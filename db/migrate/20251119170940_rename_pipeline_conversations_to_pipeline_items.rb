class RenamePipelineConversationsToPipelineItems < ActiveRecord::Migration[7.1]
  def change
    # Rename the table
    rename_table :pipeline_conversations, :pipeline_items

    # Rename the foreign key column in stage_movements
    rename_column :stage_movements, :pipeline_conversation_id, :pipeline_item_id
  end
end
