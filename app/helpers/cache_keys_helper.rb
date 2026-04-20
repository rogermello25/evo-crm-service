module CacheKeysHelper
  def get_prefixed_cache_key(_deprecated = nil, key)
    "idb-cache-key-#{key}"
  end

  def fetch_value_for_key(_deprecated = nil, key)
    prefixed_cache_key = get_prefixed_cache_key(nil, key)
    value_from_cache = Redis::Alfred.get(prefixed_cache_key)

    return value_from_cache if value_from_cache.present?

    # zero epoch time: 1970-01-01 00:00:00 UTC
    '0000000000000'
  end
end
