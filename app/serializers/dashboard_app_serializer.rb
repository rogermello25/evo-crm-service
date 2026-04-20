# frozen_string_literal: true

module DashboardAppSerializer
  extend self

  def serialize(dashboard_app, **options)
    return nil unless dashboard_app

    {
      id: dashboard_app.id,
      title: dashboard_app.title,
      display_type: dashboard_app.display_type,
      sidebar_menu: dashboard_app.sidebar_menu,
      sidebar_position: dashboard_app.sidebar_position,
      content: dashboard_app.content || {},
      user_id: dashboard_app.user_id,
      created_at: dashboard_app.created_at&.iso8601,
      updated_at: dashboard_app.updated_at&.iso8601
    }
  end

  def serialize_collection(dashboard_apps, **options)
    return [] unless dashboard_apps

    dashboard_apps.map { |app| serialize(app, **options) }
  end
end
