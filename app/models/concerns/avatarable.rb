# frozen_string_literal: true

module Avatarable
  extend ActiveSupport::Concern
  include Rails.application.routes.url_helpers

  included do
    has_one_attached :avatar
    validate :acceptable_avatar, if: -> { avatar.changed? }
    after_save :fetch_avatar_from_gravatar
  end

  def avatar_url
    return '' unless avatar.attached?

    if avatar.representable?
      begin
        return url_for(avatar.representation(resize_to_fill: [250, nil]))
      rescue StandardError => e
        Rails.logger.error("[Avatarable] Avatar variant generation failed for #{self.class.name}##{id || 'new'}: #{e.class} - #{e.message}")
      end
    end

    Rails.logger.warn("[Avatarable] Non-representable avatar fallback for #{self.class.name}##{id || 'new'}")
    url_for(avatar)
  rescue StandardError => e
    Rails.logger.error("[Avatarable] Avatar blob URL generation failed for #{self.class.name}##{id || 'new'}: #{e.class} - #{e.message}")
    ''
  end

  def fetch_avatar_from_gravatar
    return unless saved_changes.key?(:email)
    return if email.blank?

    # Incase avatar_url is supplied, we don't want to fetch avatar from gravatar
    # So we will wait for it to be processed
    Avatar::AvatarFromGravatarJob.set(wait: 30.seconds).perform_later(self, email)
  end

  def acceptable_avatar
    return unless avatar.attached?

    errors.add(:avatar, 'is too big') if avatar.byte_size > 15.megabytes

    acceptable_types = ['image/jpeg', 'image/png', 'image/gif'].freeze
    errors.add(:avatar, 'filetype not supported') unless acceptable_types.include?(avatar.content_type)
  end
end
