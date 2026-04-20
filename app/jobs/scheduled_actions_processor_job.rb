# frozen_string_literal: true

class ScheduledActionsProcessorJob < ApplicationJob
  # Temporarily using scheduled_jobs queue until scheduler pod is updated with scheduled_actions queue
  queue_as :scheduled_jobs

  # Process all due scheduled actions
  def perform(scheduled_action_id = nil)
    if scheduled_action_id
      # Process specific action (used for retries)
      process_single_action(scheduled_action_id)
    else
      # Process all due actions
      process_due_actions
    end
  end

  private

  def process_single_action(scheduled_action_id)
    scheduled_action = ScheduledAction.find_by(id: scheduled_action_id)
    return unless scheduled_action

    Rails.logger.info "Processing scheduled action: #{scheduled_action.id}"
    ScheduledActions::ExecutorService.new(scheduled_action).execute
  end

  def process_due_actions
    # Find all scheduled actions that are due
    due_actions = ScheduledAction.due.limit(100)

    Rails.logger.info "Found #{due_actions.count} due scheduled actions"

    due_actions.find_each do |scheduled_action|
      begin
        Rails.logger.info "Processor: About to execute scheduled action #{scheduled_action.id}"
        result = ScheduledActions::ExecutorService.new(scheduled_action).execute
        Rails.logger.info "Processor: Execute returned #{result} for action #{scheduled_action.id}"
      rescue StandardError => e
        Rails.logger.error "Error processing scheduled action #{scheduled_action.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
end

