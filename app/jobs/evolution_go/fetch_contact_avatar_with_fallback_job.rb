class EvolutionGo::FetchContactAvatarWithFallbackJob < ApplicationJob
  queue_as :low

  def perform(contact_id, primary_number, fallback_number, api_url, instance_token)
    contact = Contact.find_by(id: contact_id)
    return unless contact
    return if contact.avatar.attached?

    Rails.logger.info "Evolution Go Fallback Job: Fetching avatar for contact #{contact.id} (primary: #{primary_number}, fallback: #{fallback_number})"

    # Try primary number first
    profile_picture_url = fetch_profile_picture_from_evolution_go(primary_number, api_url, instance_token, "primary")

    # If primary failed and we have a fallback, try fallback
    if profile_picture_url.blank? && fallback_number.present?
      Rails.logger.info "Evolution Go Fallback Job: Primary number failed, trying fallback #{fallback_number}"
      profile_picture_url = fetch_profile_picture_from_evolution_go(fallback_number, api_url, instance_token, "fallback")
    end

    if profile_picture_url.present?
      Rails.logger.info "Evolution Go Fallback Job: Scheduling avatar download for contact #{contact.id}"
      Avatar::AvatarFromUrlJob.perform_later(contact, profile_picture_url)
    else
      Rails.logger.debug { "Evolution Go Fallback Job: No profile picture available for contact #{contact.id} (tried primary: #{primary_number}, fallback: #{fallback_number})" }
    end
  rescue StandardError => e
    Rails.logger.error "Evolution Go Fallback Job: Failed to fetch avatar for contact #{contact_id}: #{e.message}"
  end

  private

  def fetch_profile_picture_from_evolution_go(number, api_url, instance_token, attempt_type)
    Rails.logger.debug { "Evolution Go Fallback Job: Calling /user/avatar for #{attempt_type} number #{number}" }

    avatar_url = "#{api_url}/user/avatar"

    request_body = {
      number: number,
      preview: false
    }

    uri = URI.parse(avatar_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request['apikey'] = instance_token
    request['Content-Type'] = 'application/json'
    request.body = request_body.to_json

    Rails.logger.debug { "Evolution Go Fallback Job: Avatar request (#{attempt_type}) - URL: #{avatar_url}" }

    response = http.request(request)
    Rails.logger.debug { "Evolution Go Fallback Job: Avatar response (#{attempt_type}) - Code: #{response.code}" }

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn "Evolution Go Fallback Job: Avatar request (#{attempt_type}) failed - Status: #{response.code}"
      return nil
    end

    response_data = JSON.parse(response.body)

    # Extract URL from Evolution Go response format
    profile_picture_url = response_data.dig('data', 'url')

    if profile_picture_url.present?
      Rails.logger.info "Evolution Go Fallback Job: Profile picture URL retrieved (#{attempt_type})"
      profile_picture_url
    else
      Rails.logger.debug { "Evolution Go Fallback Job: No profile picture available for #{attempt_type} number #{number}" }
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Evolution Go Fallback Job: Avatar response JSON parse error (#{attempt_type}): #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.error "Evolution Go Fallback Job: Avatar request error (#{attempt_type}): #{e.class} - #{e.message}"
    nil
  end
end
