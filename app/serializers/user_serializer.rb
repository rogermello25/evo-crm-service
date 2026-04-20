# frozen_string_literal: true

# UserSerializer - Optimized serialization for User resources
#
# Plain Ruby module for Oj direct serialization
#
# Usage:
#   UserSerializer.serialize(@user)
#
module UserSerializer
  extend self

  # Serialize single User (simple, frequently used)
  #
  # @param user [User] User to serialize
  # @param options [Hash] Serialization options
  # @option options [Boolean] :include_custom_attributes Include custom_attributes
  #
  # @return [Hash] Serialized user ready for Oj
  #
  def serialize(user, include_custom_attributes: false)
    result = {
      id: user.id,
      name: user.name,
      display_name: user.display_name,
      email: user.email,
      role: user.role,
      confirmed: user.confirmed?,
      availability_status: user.availability_status,
      auto_offline: user.auto_offline,
      avatar_url: user.avatar_url,
      available_name: user.available_name,
      created_at: user.created_at.to_i,
      updated_at: user.updated_at.to_i
    }

    # Conditionally include custom_attributes
    if include_custom_attributes
      result['custom_attributes'] = user.custom_attributes || {}
    end

    result
  end

  # Serialize collection of Users
  #
  # @param users [Array<User>, ActiveRecord::Relation]
  # @param options [Hash] Same options as serialize method
  #
  # @return [Array<Hash>] Array of serialized users
  #
  def serialize_collection(users, **options)
    return [] unless users

    users.map { |user| serialize(user, **options) }
  end
end
