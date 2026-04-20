class Inboxes::UpdateWidgetPreChatCustomFieldsJob < ApplicationJob
  queue_as :default

  def perform(custom_attribute)
    attribute_key = custom_attribute['attribute_key']
    current_job_id = job_id

    processed_widgets = 0
    updated_widgets = 0
    skipped_widgets = 0

    Rails.logger.info(
      "[WidgetPreChatCustomFields][update] start job_id=#{current_job_id} " \
      "attribute_key=#{attribute_key} behavior=update_if_exists_skip_if_missing"
    )

    Channel::WebWidget.where(pre_chat_form_enabled: true).find_each do |web_widget|
      processed_widgets += 1

      pre_chat_options = (web_widget.pre_chat_form_options || {}).with_indifferent_access
      pre_chat_fields = Array(pre_chat_options['pre_chat_fields'])

      index = pre_chat_fields.find_index do |pre_chat_field|
        pre_chat_field.is_a?(Hash) && pre_chat_field.with_indifferent_access['name'] == attribute_key
      end

      if index.nil?
        skipped_widgets += 1
        next
      end

      pre_chat_fields[index] = pre_chat_fields[index].deep_merge(
        {
          'label' => custom_attribute['attribute_display_name'],
          'placeholder' => custom_attribute['attribute_display_name'],
          'values' => custom_attribute['attribute_values'],
          'regex_pattern' => custom_attribute['regex_pattern'],
          'regex_cue' => custom_attribute['regex_cue']
        }
      )

      web_widget.pre_chat_form_options = pre_chat_options.merge('pre_chat_fields' => pre_chat_fields)
      web_widget.save!
      updated_widgets += 1

      Rails.logger.info(
        "[WidgetPreChatCustomFields][update] updated job_id=#{current_job_id} " \
        "web_widget_id=#{web_widget.id} attribute_key=#{attribute_key}"
      )
    end

    Rails.logger.info(
      "[WidgetPreChatCustomFields][update] finish job_id=#{current_job_id} attribute_key=#{attribute_key} " \
      "processed_widgets=#{processed_widgets} updated_widgets=#{updated_widgets} skipped_widgets=#{skipped_widgets}"
    )
  rescue StandardError => e
    Rails.logger.error(
      "[WidgetPreChatCustomFields][update] error job_id=#{current_job_id} attribute_key=#{attribute_key} " \
      "error_class=#{e.class} error_message=#{e.message}"
    )
    Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
    raise
  end
end
