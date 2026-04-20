class Whatsapp::TemplateProcessingService
  attr_reader :template_message

  def initialize(template_message)
    @template_message = template_message
  end

  def process
    return {} if template_message.blank?

    {
      template_name: template_message[:name],
      template_namespace: template_message[:namespace],
      template_language: template_message[:language],
      template_components: process_components(template_message[:components])
    }
  end

  private

  def process_components(components)
    return [] if components.blank?

    components.map do |component|
      processed_component = {
        type: component[:type],
        parameters: process_parameters(component[:parameters])
      }

      # Adicionar texto se presente
      processed_component[:text] = component[:text] if component[:text].present?

      # Adicionar formato se presente (para componentes de cabeçalho)
      processed_component[:format] = component[:format] if component[:format].present?

      # Processar botões se presentes
      if component[:buttons].present?
        processed_component[:buttons] = component[:buttons].map do |button|
          process_button(button)
        end
      end

      # Processar sub_tipo e index se presentes (para componentes de botões)
      if component[:type].to_s.downcase == 'button'
        processed_component[:sub_type] = component[:sub_type] if component[:sub_type].present?
        processed_component[:index] = component[:index] if component[:index].present?
      end

      processed_component
    end
  end

  def process_parameters(parameters)
    return [] if parameters.blank?

    parameters.map do |param|
      case param[:type].to_s.downcase
      when 'text'
        {
          type: 'text',
          text: param[:text],
          parameter_name: param[:parameter_name]
        }.compact
      when 'image'
        {
          type: 'image',
          image: { link: param[:image][:link] },
          parameter_name: param[:parameter_name]
        }.compact
      when 'document'
        document_param = {
          type: 'document',
          document: { link: param[:document][:link] },
          parameter_name: param[:parameter_name]
        }.compact

        document_param[:filename] = param[:filename] if param[:filename].present?
        document_param
      when 'video'
        {
          type: 'video',
          video: { link: param[:video][:link] },
          parameter_name: param[:parameter_name]
        }.compact
      when 'location'
        {
          type: 'location',
          location: {
            latitude: param[:location][:latitude],
            longitude: param[:location][:longitude],
            name: param[:location][:name],
            address: param[:location][:address]
          }.compact,
          parameter_name: param[:parameter_name]
        }.compact
      when 'currency'
        {
          type: 'currency',
          currency: {
            fallback_value: param[:currency][:fallback_value],
            code: param[:currency][:code],
            amount_1000: param[:currency][:amount_1000]
          }.compact,
          parameter_name: param[:parameter_name]
        }.compact
      when 'date_time'
        {
          type: 'date_time',
          date_time: {
            fallback_value: param[:date_time][:fallback_value]
          }.compact,
          parameter_name: param[:parameter_name]
        }.compact
      when 'payload', 'quick_reply'
        {
          type: 'payload',
          payload: param[:payload] || param[:text],
          parameter_name: param[:parameter_name]
        }.compact
      else
        {
          type: param[:type],
          value: param[:text] || param[:value] || param[:payload],
          parameter_name: param[:parameter_name]
        }.compact
      end
    end
  end

  def process_button(button)
    button_data = {
      type: button[:type],
      text: button[:text]
    }

    case button[:type].to_s.downcase
    when 'url'
      button_data[:url] = button[:url]
    when 'phone_number'
      button_data[:phone_number] = button[:phone_number]
    when 'quick_reply', 'reply'
      button_data[:payload] = button[:payload]
      button_data[:id] = button[:id] if button[:id].present?
    end

    button_data
  end
end
