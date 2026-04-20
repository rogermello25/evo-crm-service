class Internal::RemoveStaleRedisKeysService
  def perform
    Rails.logger.info 'Removing stale redis keys'
    range_start = (Time.zone.now - OnlineStatusTracker::PRESENCE_DURATION).to_i
    # exclusive minimum score is specified by prefixing (
    # we are clearing old records because this could clogg up the sorted set
    ::Redis::Alfred.zremrangebyscore(
      OnlineStatusTracker.presence_key('Contact'),
      '-inf',
      "(#{range_start}"
    )
  end
end
