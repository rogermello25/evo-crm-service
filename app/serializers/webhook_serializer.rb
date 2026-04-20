# frozen_string_literal: true

# WebhookSerializer - Optimized serialization for Webhook resources
#
# Plain Ruby module for Oj direct serialization
#
# Usage:
#   WebhookSerializer.serialize(@webhook)
#
module WebhookSerializer
  extend self

  # Serialize single Webhook
  #
  # @param webhook [Webhook] Webhook to serialize
  # @param options [Hash] Serialization options
  #
  # @return [Hash] Serialized webhook ready for Oj
  #
  def serialize(webhook)
    {
      id: webhook.id,
      inbox_id: webhook.inbox_id,
      url: webhook.url,
      webhook_type: webhook.webhook_type,
      subscriptions: webhook.subscriptions,
      created_at: webhook.created_at&.iso8601,
      updated_at: webhook.updated_at&.iso8601
    }
  end

  # Serialize collection of Webhooks
  #
  # @param webhooks [Array<Webhook>, ActiveRecord::Relation]
  #
  # @return [Array<Hash>] Array of serialized webhooks
  #
  def serialize_collection(webhooks)
    return [] unless webhooks

    webhooks.map { |webhook| serialize(webhook) }
  end
end
