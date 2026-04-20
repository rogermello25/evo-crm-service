class OnlineStatusTracker
  # NOTE: You can customise the environment variable to keep your agents/contacts as online for longer
  PRESENCE_DURATION = ENV.fetch('PRESENCE_DURATION', 20).to_i.seconds

  # presence : sorted set with timestamp as the score & object id as value

  # obj_type: Contact | User
  def self.update_presence(obj_type, obj_id)
    current_timestamp = Time.now.to_i
    ::Redis::Alfred.zadd(presence_key(obj_type), current_timestamp, obj_id)
  end

  def self.get_presence(obj_type, obj_id)
    connected_time = ::Redis::Alfred.zscore(presence_key(obj_type), obj_id)
    connected_time && connected_time > (Time.zone.now - PRESENCE_DURATION).to_i
  end

  def self.presence_key(type)
    case type
    when 'Contact'
      ::Redis::Alfred::ONLINE_PRESENCE_CONTACTS
    else
      ::Redis::Alfred::ONLINE_PRESENCE_USERS
    end
  end

  # online status : online | busy | offline
  # redis hash with obj_id key && status as value

  def self.set_status(user_id, status)
    ::Redis::Alfred.hset(status_key, user_id, status)
  end

  def self.get_status(user_id)
    ::Redis::Alfred.hget(status_key, user_id)
  end

  def self.status_key
    ::Redis::Alfred::ONLINE_STATUS
  end

  def self.get_available_contact_ids
    range_start = (Time.zone.now - PRESENCE_DURATION).to_i
    # exclusive minimum score is specified by prefixing (
    # we are clearing old records because this could clogg up the sorted set
    ::Redis::Alfred.zremrangebyscore(presence_key('Contact'), '-inf', "(#{range_start}")
    ::Redis::Alfred.zrangebyscore(presence_key('Contact'), range_start, '+inf')
  end

  def self.get_available_contacts
    # returns {id1: 'online', id2: 'online'}
    get_available_contact_ids.index_with { |_id| 'online' }
  end

  def self.get_available_users
    user_ids = get_available_user_ids

    return {} if user_ids.blank?

    user_availabilities = ::Redis::Alfred.hmget(status_key, user_ids)
    user_ids.map.with_index { |id, index| [id, (user_availabilities[index] || get_availability_from_db(id))] }.to_h
  end

  def self.get_availability_from_db(user_id)
    availability = User.find_by(id: user_id)&.availability || 'offline'
    set_status(user_id, availability)
    availability
  end

  def self.get_available_user_ids
    range_start = (Time.zone.now - PRESENCE_DURATION).to_i
    user_ids = ::Redis::Alfred.zrangebyscore(presence_key('User'), range_start, '+inf')
    # since we are dealing with redis items as string, casting to string
    # auto_offline is always false for User (see UserAttributeHelpers), so include all users
    user_ids += User.pluck(:id).map(&:to_s)
    user_ids.uniq
  end

  def self.concurrent_users_count
    range_start = (Time.zone.now - PRESENCE_DURATION).to_i
    ::Redis::Alfred.zremrangebyscore(presence_key('User'), '-inf', "(#{range_start}")
    ::Redis::Alfred.zcount(presence_key('User'), range_start, '+inf')
  end
end
