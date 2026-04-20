class GlobalConfigService
  def self.load(config_key, default_value)
    # Priority 1: Check database first (user-configured values take precedence)
    config = GlobalConfig.get(config_key)[config_key]
    # Use !nil? instead of present? to allow false boolean values
    return config unless config.nil?

    # Priority 2: Check environment variables as fallback
    env_value = ENV.fetch(config_key, nil)
    return env_value if env_value.present?

    # Priority 3: Return default value if not found anywhere
    default_value
  rescue ActiveRecord::ActiveRecordError, NameError, PG::Error => _e
    # Database or model not available yet (boot phase, before migrations, etc.)
    ENV.fetch(config_key, default_value)
  end
end
