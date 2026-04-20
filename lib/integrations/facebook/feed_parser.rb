# frozen_string_literal: true

# Parser for Facebook feed webhook events (posts and comments)
# Handles both regular posts and boosted posts (effective_object_story_id)
class Integrations::Facebook::FeedParser
  attr_reader :change_value

  def initialize(change_value)
    @change_value = change_value.with_indifferent_access
  end

  def item
    @change_value['item']
  end

  def verb
    @change_value['verb']
  end

  def post_id
    # IMPORTANT: For boosted posts, Facebook sends effective_object_story_id instead of post_id
    # We normalize to use effective_object_story_id when present, otherwise use post_id
    normalized_post_id
  end

  def normalized_post_id
    @normalized_post_id ||= begin
      id = @change_value['effective_object_story_id'].presence || @change_value['post_id']
      Rails.logger.info("Facebook FeedParser: Using #{@change_value['effective_object_story_id'].present? ? 'effective_object_story_id' : 'post_id'} = #{id}") if id.present?
      id
    end
  end

  def is_boosted?
    @change_value['effective_object_story_id'].present?
  end

  def comment_id
    @change_value['comment_id']
  end

  def message
    @change_value['message']
  end

  def from_id
    @change_value.dig('from', 'id')
  end

  def from_name
    @change_value.dig('from', 'name')
  end

  def created_time
    @change_value['created_time']
  end

  def parent_id
    @change_value['parent_id']
  end

  def is_reply?
    parent_id.present?
  end

  def valid?
    return false if item.blank?
    return false if verb.blank?
    return false if normalized_post_id.blank?

    # For comment events, comment_id is required
    if item == 'comment'
      return false if comment_id.blank?
    end

    true
  end

  def comment_event?
    item == 'comment'
  end

  def post_event?
    %w[status post photo video].include?(item)
  end

  def add_event?
    verb == 'add'
  end

  def edited_event?
    verb == 'edited'
  end

  def remove_event?
    verb == 'remove'
  end
end

# Sample Feed Change Payload:
# {
#   "field": "feed",
#   "value": {
#     "item": "comment",
#     "verb": "add",
#     "post_id": "POST_ID",                    # Regular post
#     "effective_object_story_id": "POST_ID",  # Boosted post (takes precedence)
#     "comment_id": "COMMENT_ID",
#     "message": "Comment text",
#     "from": {
#       "id": "USER_ID",
#       "name": "User Name"
#     },
#     "created_time": 1234567890,
#     "parent_id": "PARENT_COMMENT_ID"         # If reply to another comment
#   }
# }

