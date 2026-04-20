class GlobalConfig
  VERSION = 'V1'.freeze
  KEY_PREFIX = 'GLOBAL_CONFIG'.freeze
  DEFAULT_EXPIRY = 1.day

  class << self
    def get(*args)
      config_keys = *args
      config = {}

      config_keys.each do |config_key|
        config[config_key] = load_from_cache(config_key)
      end

      typecast_config(config)
      config.with_indifferent_access
    end

    def get_value(arg)
      load_from_cache(arg)
    end

    def set(config_key, config_value)
      installation_config = InstallationConfig.find_or_initialize_by(name: config_key)
      installation_config.value = config_value
      installation_config.save!

      # Clear cache for this specific key
      cache_key = "#{VERSION}:#{KEY_PREFIX}:#{config_key}"
      $alfred.with { |conn| conn.del(cache_key) }
    end

    def clear_cache
      cached_keys = $alfred.with { |conn| conn.keys("#{VERSION}:#{KEY_PREFIX}:*") }
      (cached_keys || []).each do |cached_key|
        $alfred.with { |conn| conn.expire(cached_key, 0) }
      end
    end

    private

    def typecast_config(config)
      general_configs = ConfigLoader.new.general_configs
      config.each do |config_key, config_value|
        config_type = general_configs.find { |c| c['name'] == config_key }&.dig('type')
        # Only typecast if value is not nil (nil means not set, should remain nil)
        if config_type == 'boolean' && !config_value.nil?
          config[config_key] = ActiveRecord::Type::Boolean.new.cast(config_value)
        end
      end
    end

    def load_from_cache(config_key)
      cache_key = "#{VERSION}:#{KEY_PREFIX}:#{config_key}"
      cached_value = $alfred.with { |conn| conn.get(cache_key) }

      if cached_value.blank?
        value_from_db = db_fallback(config_key)
        cached_value = { value: value_from_db }.to_json
        $alfred.with { |conn| conn.set(cache_key, cached_value, { ex: DEFAULT_EXPIRY }) }
      end

      JSON.parse(cached_value)['value']
    end

    def db_fallback(config_key)
      # Use unscoped to avoid default_scope ordering issues and get the most recent record
      InstallationConfig.unscoped.where(name: config_key).order(created_at: :desc).first&.value
    end
  end
end
