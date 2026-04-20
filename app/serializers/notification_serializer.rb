# frozen_string_literal: true

# NotificationSerializer - Optimized serialization for Notification resources
#
# Plain Ruby module for Oj direct serialization
#
# Usage:
#   NotificationSerializer.serialize(@notification)
#
module NotificationSerializer
  extend self

  # Serialize single Notification
  #
  # @param notification [Notification] Notification to serialize
  # @param options [Hash] Serialization options
  # @option options [Boolean] :include_actors Include primary and secondary actors
  #
  # @return [Hash] Serialized notification ready for Oj
  #
  def serialize(notification, include_actors: true)
    result = {
      id: notification.id,
      notification_type: notification.notification_type,
      primary_actor_type: notification.primary_actor_type,
      primary_actor_id: notification.primary_actor_id,
      secondary_actor_type: notification.secondary_actor_type,
      secondary_actor_id: notification.secondary_actor_id,
      read_at: notification.read_at&.to_i,
      created_at: notification.created_at.to_i,
      updated_at: notification.updated_at.to_i,
      push_message_title: notification.push_message_title
    }

    # Include actors if loaded and requested
    if include_actors
      if notification.primary_actor.present?
        result['primary_actor'] = serialize_actor(notification.primary_actor)
      end

      if notification.secondary_actor.present?
        result['secondary_actor'] = serialize_actor(notification.secondary_actor)
      end
    end

    result
  end

  # Serialize collection of Notifications
  #
  # @param notifications [Array<Notification>, ActiveRecord::Relation]
  # @param options [Hash] Same options as serialize method
  #
  # @return [Array<Hash>] Array of serialized notifications
  #
  def serialize_collection(notifications, **options)
    return [] unless notifications

    notifications.map { |notification| serialize(notification, **options) }
  end

  private

  # Serialize polymorphic actor
  def serialize_actor(actor)
    case actor
    when User
      UserSerializer.serialize(actor)
    when Contact
      { id: actor.id, name: actor.name, type: 'Contact' }
    when Conversation
      { id: actor.id, display_id: actor.display_id, type: 'Conversation' }
    when Message
      { id: actor.id, content: actor.content&.truncate(50), type: 'Message' }
    else
      { id: actor.id, type: actor.class.name }
    end
  end
end
