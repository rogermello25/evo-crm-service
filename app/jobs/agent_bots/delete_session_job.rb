class AgentBots::DeleteSessionJob < ApplicationJob
  queue_as :default

  def perform(agent_bot_id, session_id, api_key, outgoing_url)
    Rails.logger.info "[DeleteSessionJob] Starting session deletion for session_id: #{session_id}, agent_bot_id: #{agent_bot_id}"

    # Extract base processor URL (remove /message/send if present)
    processor_url = outgoing_url.gsub(%r{/message/send$}, '')
    session_url = "#{processor_url}/sessions/#{session_id}"

    Rails.logger.debug "[DeleteSessionJob] Deleting session at URL: #{session_url}"

    uri = URI(session_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 10
    http.open_timeout = 5

    request = Net::HTTP::Delete.new(uri)
    request['Content-Type'] = 'application/json'

    if api_key.present?
      request['Authorization'] = "Bearer #{api_key}"
      Rails.logger.debug "[DeleteSessionJob] Using API Key authentication"
    else
      Rails.logger.warn "[DeleteSessionJob] No API key provided for session deletion"
    end

    response = http.request(request)

    case response.code.to_i
    when 204
      Rails.logger.info "[DeleteSessionJob] Session #{session_id} deleted successfully from processor"
    when 404
      Rails.logger.warn "[DeleteSessionJob] Session #{session_id} not found in processor (may have been already deleted)"
    else
      Rails.logger.error "[DeleteSessionJob] Failed to delete session #{session_id}: HTTP #{response.code}"
      Rails.logger.error "[DeleteSessionJob] Response body: #{response.body}"
    end
  rescue StandardError => e
    Rails.logger.error "[DeleteSessionJob] Error deleting session #{session_id}: #{e.message}"
    Rails.logger.error "[DeleteSessionJob] Backtrace: #{e.backtrace.first(5).join("\n")}"
    # Don't re-raise - we don't want to retry session deletions that fail
  end
end
