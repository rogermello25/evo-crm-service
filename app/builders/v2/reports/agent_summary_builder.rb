class V2::Reports::AgentSummaryBuilder < V2::Reports::BaseSummaryBuilder
  pattr_initialize [:account, :params!]

  def build
    load_data
    prepare_report
  end

  private

  attr_reader :conversations_count, :resolved_count,
              :avg_resolution_time, :avg_first_response_time, :avg_reply_time

  def fetch_conversations_count
    Conversation.where(created_at: range).group('assignee_id').count
  end

  def prepare_report
    User.all.map do |user|
      build_agent_stats(user)
    end
  end

  def build_agent_stats(user)
    user_id = user.id
    {
      id: user_id,
      conversations_count: conversations_count[user_id] || 0,
      resolved_conversations_count: resolved_count[user_id] || 0,
      avg_resolution_time: avg_resolution_time[user_id],
      avg_first_response_time: avg_first_response_time[user_id],
      avg_reply_time: avg_reply_time[user_id]
    }
  end

  def group_by_key
    :user_id
  end
end
