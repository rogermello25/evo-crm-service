# frozen_string_literal: true

module ScheduledActionTemplateSerializer
  extend self

  def serialize(template, **options)
    return nil unless template

    data = {
      id: template.id,
      name: template.name,
      description: template.description,
      action_type: template.action_type,
      default_delay_minutes: template.default_delay_minutes,
      payload: template.payload || {},
      is_default: template.is_default,
      is_public: template.is_public,
      created_at: template.created_at&.iso8601,
      updated_at: template.updated_at&.iso8601
    }

    if options[:include_creator] && template.creator
      data[:creator] = {
        id: template.creator.id,
        name: template.creator.name,
        email: template.creator.email
      }
    end

    data
  end

  def serialize_collection(templates, **options)
    return [] unless templates

    templates.map { |template| serialize(template, **options) }
  end
end
