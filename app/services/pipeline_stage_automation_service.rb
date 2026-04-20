# frozen_string_literal: true

# Service to execute pipeline stage automations configured on AI Agent
# This runs when a conversation is moved to a new stage in the pipeline
class PipelineStageAutomationService
  def initialize(pipeline_item:, new_stage:, user: nil)
    @pipeline_item = pipeline_item
    @new_stage = new_stage
    @user = user
    @agent_bot = nil
    @agent_id = nil
    @ai_agent_config = nil
    @automation_config = nil
  end

  def execute
    return unless should_execute?
    return unless @pipeline_item.conversation?

    load_agent_configuration
    return unless @automation_config.present?

    stage_automation = find_stage_automation
    return unless stage_automation.present?

    Rails.logger.info "[PipelineStageAutomation] Executing automation for pipeline_item #{@pipeline_item.id}, " \
                       "stage #{@new_stage.name}, agent_id #{@agent_id}"

    create_automatic_tasks(stage_automation)
    notify_team(stage_automation) if stage_automation['notify_team']

    Rails.logger.info "[PipelineStageAutomation] Automation completed for pipeline_item #{@pipeline_item.id}"
  rescue StandardError => e
    Rails.logger.error "[PipelineStageAutomation] Error executing automation: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    # Don't raise - automation failures shouldn't block pipeline operations
  end

  private

  def should_execute?
    return false unless @pipeline_item.present?
    return false unless @new_stage.present?
    return false unless @pipeline_item.conversation_id.present?

    true
  end

  def load_agent_configuration
    conversation = @pipeline_item.conversation
    return unless conversation&.inbox

    inbox = conversation.inbox
    agent_bot_inbox = inbox.agent_bot_inbox
    return unless agent_bot_inbox

    @agent_bot = agent_bot_inbox.agent_bot
    return unless @agent_bot

    # Get AI agent ID from bot_config
    @agent_id = @agent_bot.bot_config&.dig('agent_id')
    return unless @agent_id.present?

    # Fetch AI agent config from evo-ai-core-service
    begin
      @ai_agent_config = EvoAiCoreService.get_agent(@agent_id)
    rescue StandardError => e
      Rails.logger.error "[PipelineStageAutomation] Failed to fetch AI agent #{@agent_id}: #{e.message}"
      return
    end

    return unless @ai_agent_config.is_a?(Hash)

    @automation_config = @ai_agent_config.dig('config', 'pipeline_automation')
  end

  def find_stage_automation
    return nil unless @automation_config.is_a?(Array)

    # Find the automation rule for this pipeline and stage
    @automation_config.each do |rule|
      next unless rule['pipelineId'] == @new_stage.pipeline_id.to_s ||
                  rule['pipelineId'] == @new_stage.pipeline_id

      stage_autos = rule['stageAutomations']
      next unless stage_autos.is_a?(Array)

      # Return the first matching stage automation
      return stage_autos.find do |stage_auto|
        stage_auto['stageId'] == @new_stage.id.to_s || stage_auto['stageId'] == @new_stage.id
      end
    end
    nil
  end

  def create_automatic_tasks(stage_automation)
    tasks = stage_automation['createTasks']
    return unless tasks.is_a?(Array) && tasks.any?

    tasks.each do |task_config|
      create_task(task_config)
    end
  end

  def create_task(task_config)
    task_params = {
      title: task_config['title'] || "Task for #{@new_stage.name}",
      task_type: normalize_task_type(task_config['taskType']),
      priority: normalize_priority(task_config['priority']),
      status: :pending,
      due_date: calculate_due_date(task_config['dueDays']),
      description: task_config['description'],
      pipeline_item_id: @pipeline_item.id,
      created_by_id: @user&.id || system_user_id
    }

    task = PipelineTask.create!(task_params)

    Rails.logger.info "[PipelineStageAutomation] Created task #{task.id} for pipeline_item #{@pipeline_item.id}"

    # Send notification for assigned task
    PipelineTasks::NotificationService.new(task: task, notification_type: 'pipeline_task_assigned').perform

    task
  rescue StandardError => e
    Rails.logger.error "[PipelineStageAutomation] Failed to create task: #{e.message}"
    nil
  end

  def notify_team(stage_automation)
    # TODO: Implement team notification based on stage_automation config
    # This would typically:
    # 1. Look up the team from the inbox or stage config
    # 2. Send a notification (email, push, etc.)
    # 3. Possibly create a conversation note

    Rails.logger.info "[PipelineStageAutomation] Team notification triggered for pipeline_item #{@pipeline_item.id}"
  end

  def normalize_task_type(task_type)
    case task_type&.to_s
    when 'call' then :call
    when 'email' then :email
    when 'meeting' then :meeting
    when 'follow_up' then :follow_up
    when 'note' then :note
    else :other
    end
  end

  def normalize_priority(priority)
    case priority&.to_s
    when 'low' then :low
    when 'medium' then :medium
    when 'high' then :high
    when 'urgent' then :urgent
    else :medium
    end
  end

  def calculate_due_date(due_days)
    return nil unless due_days.present?

    due_days.to_i.days.from_now
  end

  def system_user_id
    # Find or create a system user for automation actions
    @system_user ||= User.find_by(email: 'system@evo.ai') || User.first&.id
  end
end