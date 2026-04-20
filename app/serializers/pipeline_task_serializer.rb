# frozen_string_literal: true

# PipelineTaskSerializer - Optimized serialization for PipelineTask resources
#
# Plain Ruby module for Oj direct serialization
#
# Usage:
#   PipelineTaskSerializer.serialize(@pipeline_task, include_parent: true, include_subtasks: true)
#
module PipelineTaskSerializer
  extend self

  # Serialize single PipelineTask
  #
  # @param pipeline_task [PipelineTask] PipelineTask to serialize
  # @param options [Hash] Serialization options
  # @option options [Boolean] :include_pipeline_item Include pipeline item details
  # @option options [Boolean] :include_parent Include parent task info
  # @option options [Boolean] :include_subtasks Include subtasks recursively
  #
  # @return [Hash] Serialized pipeline task ready for Oj
  #
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def serialize(pipeline_task, include_pipeline_item: false, include_parent: false, include_subtasks: false)
    result = {
      id: pipeline_task.id,
      pipeline_item_id: pipeline_task.pipeline_item_id,
      title: pipeline_task.title,
      description: pipeline_task.description,
      task_type: pipeline_task.task_type,
      status: pipeline_task.status,
      priority: pipeline_task.priority,
      due_date: pipeline_task.due_date&.iso8601,
      assigned_to_id: pipeline_task.assigned_to_id,
      completed_at: pipeline_task.completed_at&.iso8601,
      created_at: pipeline_task.created_at&.iso8601,
      updated_at: pipeline_task.updated_at&.iso8601,
      
      # Hierarchy fields
      parent_task_id: pipeline_task.parent_task_id,
      position: pipeline_task.position,
      depth: pipeline_task.depth,
      is_root: pipeline_task.root_task?,
      has_subtasks: pipeline_task.has_subtasks?,
      subtask_count: pipeline_task.subtask_count,
      completion_percentage: pipeline_task.completion_percentage,
      
      # Computed fields
      overdue: pipeline_task.overdue?,
      due_soon: pipeline_task.due_soon?,
      days_until_due: pipeline_task.days_until_due,
      hours_until_due: pipeline_task.hours_until_due,
      
      # Related objects
      created_by: UserSerializer.serialize(pipeline_task.created_by),
      assigned_to: pipeline_task.assigned_to.present? ? UserSerializer.serialize(pipeline_task.assigned_to) : nil,
      metadata: pipeline_task.metadata
    }
    
    # Include parent task info
    if include_parent && pipeline_task.association(:parent_task).loaded? && pipeline_task.parent_task.present?
      result[:parent_task] = {
        id: pipeline_task.parent_task.id,
        title: pipeline_task.parent_task.title,
        status: pipeline_task.parent_task.status,
        due_date: pipeline_task.parent_task.due_date&.iso8601
      }
    end
    
    # Include subtasks recursively
    if include_subtasks && pipeline_task.association(:subtasks).loaded? && pipeline_task.has_subtasks?
      result[:subtasks] = pipeline_task.subtasks.map do |subtask|
        serialize(subtask, include_subtasks: true)
      end
    end
    
    # Include pipeline item
    if include_pipeline_item && pipeline_task.pipeline_item.present?
      result[:pipeline_item] = PipelineItemSerializer.serialize(pipeline_task.pipeline_item)
    end
    
    result.compact
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # Serialize collection of PipelineTasks
  #
  # @param pipeline_tasks [Array<PipelineTask>, ActiveRecord::Relation]
  # @param options [Hash] Same options as serialize method
  #
  # @return [Array<Hash>] Array of serialized pipeline tasks
  #
  def serialize_collection(pipeline_tasks, **options)
    return [] unless pipeline_tasks

    pipeline_tasks.map { |task| serialize(task, **options) }
  end
end
