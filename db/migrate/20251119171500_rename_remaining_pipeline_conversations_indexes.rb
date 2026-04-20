# frozen_string_literal: true

class RenameRemainingPipelineConversationsIndexes < ActiveRecord::Migration[7.1]
  def change
    # Renomear o índice que ficou com o nome antigo
    if index_exists?(:pipeline_items, [:conversation_id, :pipeline_id], name: 'index_pipeline_conversations_on_conversation_id_and_pipeline_id')
      rename_index :pipeline_items, 'index_pipeline_conversations_on_conversation_id_and_pipeline_id', 'index_pipeline_items_on_conversation_id_and_pipeline_id'
    end
  end
end
