class Notificame::SubscribeWebhookJob < ApplicationJob
  queue_as :default

  def perform(channel_id)
    channel = Channel::Whatsapp.find_by(id: channel_id)
    return unless channel

    channel.provider_service.subscribe_to_webhooks
  end
end
