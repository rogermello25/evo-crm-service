class Channels::Whatsapp::TemplatesSyncSchedulerJob < ApplicationJob
  queue_as :low

  def perform
    # Use message_templates table to determine last sync time
    Channel::Whatsapp.left_joins(:message_templates)
                     .group('channel_whatsapp.id')
                     .select('channel_whatsapp.*, MAX(message_templates.updated_at) as last_template_update')
                     .having('MAX(message_templates.updated_at) <= ? OR MAX(message_templates.updated_at) IS NULL', 3.hours.ago)
                     .order(Arel.sql('MAX(message_templates.updated_at) IS NULL DESC, MAX(message_templates.updated_at) ASC'))
                     .limit(Limits::BULK_EXTERNAL_HTTP_CALLS_LIMIT)
                     .each do |channel|
      Channels::Whatsapp::TemplatesSyncJob.perform_later(channel)
    end
  end
end
