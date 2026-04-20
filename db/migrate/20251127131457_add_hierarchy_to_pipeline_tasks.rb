class AddHierarchyToPipelineTasks < ActiveRecord::Migration[7.1]
  def change
    add_reference :pipeline_tasks, :parent_task, 
                  type: :uuid, 
                  foreign_key: { to_table: :pipeline_tasks }, 
                  null: true
    
    add_column :pipeline_tasks, :position, :integer, default: 0, null: false
    add_column :pipeline_tasks, :depth, :integer, default: 0, null: false
    
    add_index :pipeline_tasks, [:parent_task_id, :position]
    add_index :pipeline_tasks, [:pipeline_item_id, :parent_task_id]
  end
end
