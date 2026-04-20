class Inboxes::SyncWidgetPreChatCustomFieldsJob < ApplicationJob
  queue_as :default

  def perform(field_name)
    current_job_id = job_id

    processed_widgets = 0
    updated_widgets = 0
    skipped_widgets = 0
    removed_fields = 0

    Rails.logger.info(
      "[WidgetPreChatCustomFields][destroy] start job_id=#{current_job_id} field_name=#{field_name}"
    )

    Channel::WebWidget.where(pre_chat_form_enabled: true).find_each do |web_widget|
      processed_widgets += 1

      pre_chat_options = (web_widget.pre_chat_form_options || {}).with_indifferent_access
      pre_chat_fields = Array(pre_chat_options['pre_chat_fields'])

      filtered_fields = pre_chat_fields.reject do |field|
        field.is_a?(Hash) && field.with_indifferent_access['name'] == field_name
      end

      removed_count = pre_chat_fields.size - filtered_fields.size
      if removed_count.zero?
        skipped_widgets += 1
        next
      end

      web_widget.pre_chat_form_options = pre_chat_options.merge('pre_chat_fields' => filtered_fields)
      web_widget.save!

      updated_widgets += 1
      removed_fields += removed_count

      Rails.logger.info(
        "[WidgetPreChatCustomFields][destroy] updated job_id=#{current_job_id} " \
        "web_widget_id=#{web_widget.id} field_name=#{field_name} removed_fields=#{removed_count}"
      )
    end

    Rails.logger.info(
      "[WidgetPreChatCustomFields][destroy] finish job_id=#{current_job_id} field_name=#{field_name} " \
      "processed_widgets=#{processed_widgets} updated_widgets=#{updated_widgets} " \
      "skipped_widgets=#{skipped_widgets} removed_fields=#{removed_fields}"
    )
  rescue StandardError => e
    Rails.logger.error(
      "[WidgetPreChatCustomFields][destroy] error job_id=#{current_job_id} field_name=#{field_name} " \
      "error_class=#{e.class} error_message=#{e.message}"
    )
    Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
    raise
  end
end
