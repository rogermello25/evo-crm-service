module ApplicationHelper
  SUPPORTED_LOCALES = %w[en fr it es pt pt_BR].freeze

  def available_locales_with_name
    LANGUAGES_CONFIG.filter_map do |_key, val|
      val.slice(:name, :iso_639_1_code) if val[:enabled] && SUPPORTED_LOCALES.include?(val[:iso_639_1_code])
    end
  end

  def feature_help_urls
    features = YAML.safe_load(Rails.root.join('config/features.yml').read).freeze
    features.each_with_object({}) do |feature, hash|
      hash[feature['name']] = feature['help_url'] if feature['help_url']
    end
  end
end
