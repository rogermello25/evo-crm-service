# frozen_string_literal: true

module InstallationConfigSerializer
  extend self

  def serialize(config, **options)
    return nil unless config

    {
      name: config[:name],
      value: config[:value],
      display_name: config[:display_name] || config[:name].humanize.titleize,
      description: config[:description]
    }
  end

  def serialize_collection(configs, **options)
    return [] unless configs

    configs.map { |config| serialize(config, **options) }
  end

  def serialize_grouped(grouped_configs)
    {
      common: serialize_collection(grouped_configs[:common] || []),
      features: serialize_collection(grouped_configs[:features] || []),
      integrations: serialize_collection(grouped_configs[:integrations] || [])
    }
  end
end
