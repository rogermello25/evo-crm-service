# frozen_string_literal: true

module ChannelMessageTemplates
  extend ActiveSupport::Concern

  included do
    has_many :message_templates, as: :channel, dependent: :destroy
  end

  def active_templates
    message_templates.active.recently_created
  end

  def find_template(name)
    message_templates.active.find_by(name: name)
  end

  def create_message_template(params)
    message_templates.create!(
      name: params[:name],
      content: params[:content],
      language: params[:language] || 'pt_BR',
      category: params[:category],
      template_type: params[:template_type] || 'text',
      components: params[:components] || {},
      variables: params[:variables] || [],
      media_url: params[:media_url],
      media_type: params[:media_type],
      settings: params[:settings] || {},
      metadata: params[:metadata] || {}
    )
  end

  
  def update_message_template(template_id, params)
    template = message_templates.find(template_id)
     
    # Convert ActionController::Parameters to hash and remove nil values
    update_params = params.is_a?(ActionController::Parameters) ? params.to_h : params
    
    # Don't use compact - it removes empty arrays/hashes which we need
    # update_params = update_params.compact
    
    # Handle JSONB fields explicitly to ensure they're marked as changed
    jsonb_fields = [:components, :variables, :settings, :metadata]
    jsonb_fields.each do |field|
      field_str = field.to_s
      if update_params.key?(field_str)
        value = update_params[field_str]
        # Force Rails to recognize the change in JSONB column
        template.send("#{field}=", value)
        template.send("#{field}_will_change!")
      end
    end
    
    # Update other fields
    other_params = update_params.except(*jsonb_fields.map(&:to_s))
    template.assign_attributes(other_params) if other_params.present?
    
    # Save the template
    template.save!
    
    template.reload
    
    template
  end

  def delete_message_template(template_id)
    template = message_templates.find(template_id)
    template.destroy!
  end

  def toggle_template(template_id)
    template = message_templates.find(template_id)
    template.update!(active: !template.active)
    template
  end

  def templates_by_category(category)
    message_templates.active.by_category(category)
  end

  def most_used_templates(limit = 10)
    message_templates.active.most_used.limit(limit)
  end

  def message_templates_legacy
    message_templates.active.map(&:serialized)
  end
end
