class Pipelines::AnalyticsService
  def initialize(pipeline)
    @pipeline = pipeline
  end

  def pipeline_statistics
    {
      total_conversations: @pipeline.pipeline_items.count,
      by_stage: stage_statistics,
      performance_metrics: performance_metrics
    }
  end

  def get_conversation_analytics(date_range: 30.days.ago..Time.current)
    conversations = @pipeline.pipeline_items
                             .where(created_at: date_range)

    {
      total_added: conversations.count,
      completed: conversations.completed.count,
      average_completion_time: calculate_average_completion_time(conversations.completed),
      stage_conversion_rates: calculate_stage_conversion_rates,
      bottlenecks: identify_bottlenecks
    }
  end

  private

  def stage_statistics
    @pipeline.pipeline_stages.map do |stage|
      {
        stage_id: stage.id,
        stage_name: stage.name,
        item_count: stage.pipeline_items.count,
        average_time_in_stage: calculate_average_time_in_stage(stage),
        color: stage.color
      }
    end
  end

  def performance_metrics
    recent_conversations = @pipeline.pipeline_items
                                    .where('created_at > ?', 7.days.ago)

    {
      weekly_additions: recent_conversations.count,
      weekly_completions: recent_conversations.completed.count,
      trending_direction: calculate_trend
    }
  end

  def calculate_average_time_in_stage(stage)
    movements = StageMovement.joins(:pipeline_item)
                             .where(
                               pipeline_items: { pipeline: @pipeline },
                               from_stage: stage
                             )

    return 0 if movements.empty?

    total_time = movements.sum(&:duration_in_previous_stage)
    (total_time / movements.count).round(1)
  end

  def calculate_average_completion_time(completed_conversations)
    return 0 if completed_conversations.empty?

    total_days = completed_conversations.sum(&:days_in_pipeline)
    (total_days.to_f / completed_conversations.count).round(1)
  end

  def calculate_stage_conversion_rates
    stages = @pipeline.pipeline_stages.ordered.to_a
    conversion_rates = {}

    stages.each_with_index do |stage, index|
      next if index == stages.length - 1

      current_stage_conversations = stage.pipeline_items.count
      next_stage = stages[index + 1]
      next_stage_conversations = next_stage.pipeline_items.count

      rate = if current_stage_conversations.positive?
               ((next_stage_conversations.to_f / current_stage_conversations) * 100).round(1)
             else
               0
             end

      conversion_rates["#{stage.name}_to_#{next_stage.name}"] = rate
    end

    conversion_rates
  end

  def identify_bottlenecks
    stages_with_stats = @pipeline.pipeline_stages.map do |stage|
      avg_time = calculate_average_time_in_stage(stage)
      {
        stage_name: stage.name,
        average_time: avg_time,
        item_count: stage.pipeline_items.count
      }
    end

    stages_with_high_time = stages_with_stats.select { |stage| stage[:average_time] > 7 }
    stages_with_high_time.sort_by { |stage| -stage[:average_time] }
  end

  def calculate_trend
    current_week = @pipeline.pipeline_items
                            .where('created_at > ?', 7.days.ago).count
    previous_week = @pipeline.pipeline_items
                             .where(created_at: 14.days.ago..7.days.ago).count

    return 'stable' if previous_week.zero?

    change_percent = ((current_week - previous_week).to_f / previous_week) * 100

    case change_percent
    when 10..Float::INFINITY then 'trending_up'
    when -Float::INFINITY..-10 then 'trending_down'
    else 'stable'
    end
  end
end
