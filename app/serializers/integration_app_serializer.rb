# frozen_string_literal: true

module IntegrationAppSerializer
  extend self

  def serialize(app, **options)
    return nil unless app

    account = options[:account]

    {
      id: app.id,
      name: app.name,
      description: app.description,
      logo: app.logo,
      enabled: app.enabled?(account),
      hooks: IntegrationHookSerializer.serialize_collection(Integrations::Hook.where(app_id: app.id)),
      action: app.action,
      hook_type: app.params[:hook_type],
      allow_multiple_hooks: app.params[:allow_multiple_hooks],
      i18n_key: app.params[:i18n_key]
    }.compact
  end

  def serialize_collection(apps, **options)
    return [] unless apps

    apps.map { |app| serialize(app, **options) }
  end
end

