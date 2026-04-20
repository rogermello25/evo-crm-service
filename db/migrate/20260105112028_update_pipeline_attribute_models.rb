# frozen_string_literal: true

class UpdatePipelineAttributeModels < ActiveRecord::Migration[7.1]
  def up
    # Migrate existing records from attribute_model = 2 (old pipeline_item_attribute)
    # to attribute_model = 4 (new pipeline_item_attribute)
    # 
    # The enum values are:
    # - 0: conversation_attribute
    # - 1: contact_attribute  
    # - 2: pipeline_attribute (new - for Pipeline entity)
    # - 3: pipeline_stage_attribute (new - for PipelineStage entity)
    # - 4: pipeline_item_attribute (migrated from old value 2 - for PipelineItem entity)
    
    execute <<-SQL
      UPDATE custom_attribute_definitions
      SET attribute_model = 4
      WHERE attribute_model = 2
    SQL
    
    # Note: The enum definition in CustomAttributeDefinition model handles the mapping
    # This migration just moves existing data to the correct enum value
  end

  def down
    # Revert: migrate pipeline_item_attribute (4) back to old value (2)
    # Also migrate pipeline_stage_attribute (3) to (2) for simplicity
    execute <<-SQL
      UPDATE custom_attribute_definitions
      SET attribute_model = 2
      WHERE attribute_model IN (3, 4)
    SQL
  end
end
