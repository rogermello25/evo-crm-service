class Conversations::FilterService < FilterService
  ATTRIBUTE_MODEL = 'conversation_attribute'.freeze

  def initialize(params, user, _account = nil)
    super(params, user)
  end

  def perform
    validate_query_operator
    @conversations = query_builder(@filters['conversations'])
    mine_count, unassigned_count, all_count, = set_count_for_all_conversations
    assigned_count = all_count - unassigned_count

    {
      conversations: conversations,
      count: {
        mine_count: mine_count,
        assigned_count: assigned_count,
        unassigned_count: unassigned_count,
        all_count: all_count
      }
    }
  end

  def base_relation
    conversations = Conversation
                            .joins(:contact)  # Filter out conversations without contacts
                            .joins(:inbox)    # JOIN inboxes for channel_type filtering
                            .preload(
                              :inbox,
                              :contact,
                              :assignee,
                              :team,
                              :contact_inbox,
                              :taggings,
                              messages: { attachments: { file_attachment: :blob } },
                              pipeline_items: [:pipeline, :pipeline_stage, :stage_movements]
                            )

    Conversations::PermissionFilterService.new(
      conversations,
      @user
    ).perform
  end

  def current_page
    @params[:page] || 1
  end

  def filter_config
    {
      entity: 'Conversation',
      table_name: 'conversations'
    }
  end

  def conversations
    @conversations.sort_on_last_activity_at(:desc).page(current_page)
  end
end
