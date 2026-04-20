class Webhooks::GmailController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  # Google Cloud Pub/Sub sends POST requests
  def pubsub
    # Log EVERYTHING we receive from the webhook
    Rails.logger.info "[GMAIL_PUBSUB] ========== ORIGINAL WEBHOOK PAYLOAD =========="
    Rails.logger.info "[GMAIL_PUBSUB] Request method: #{request.method}"
    Rails.logger.info "[GMAIL_PUBSUB] Content-Type: #{request.content_type}"
    Rails.logger.info "[GMAIL_PUBSUB] Request headers: #{request.headers.to_h.select { |k, v| k.start_with?('HTTP_') || k.start_with?('CONTENT_') }.inspect}"

    # Log raw request body and parse it
    @parsed_body_json = nil
    begin
      raw_body = request.body.read
      request.body.rewind # Reset for further processing
      Rails.logger.info "[GMAIL_PUBSUB] Raw request body (first 1000 chars): #{raw_body.first(1000).inspect}"
      Rails.logger.info "[GMAIL_PUBSUB] Raw request body length: #{raw_body.length} bytes"
      Rails.logger.info "[GMAIL_PUBSUB] Raw request body encoding: #{raw_body.encoding.name}"

      # Try to parse as JSON
      begin
        @parsed_body_json = JSON.parse(raw_body)
        Rails.logger.info "[GMAIL_PUBSUB] Parsed request body (as JSON): #{@parsed_body_json.inspect}"
      rescue JSON::ParserError => e
        Rails.logger.info "[GMAIL_PUBSUB] Request body is not valid JSON: #{e.message}"
      end
    rescue StandardError => e
      Rails.logger.error "[GMAIL_PUBSUB] Error reading request body: #{e.message}"
    end

    # Log params structure
    Rails.logger.info "[GMAIL_PUBSUB] ========== PARAMS STRUCTURE =========="
    Rails.logger.info "[GMAIL_PUBSUB] Params class: #{params.class}"
    Rails.logger.info "[GMAIL_PUBSUB] Params keys: #{params.keys.inspect}"
    Rails.logger.info "[GMAIL_PUBSUB] Params (as hash): #{params.to_unsafe_h.inspect}"
    Rails.logger.info "[GMAIL_PUBSUB] Params (as JSON): #{params.to_json}"

    # Log each param key in detail
    params.keys.each do |key|
      value = params[key]
      Rails.logger.info "[GMAIL_PUBSUB] Param[#{key.inspect}]:"
      Rails.logger.info "  - Class: #{value.class}"
      Rails.logger.info "  - Value: #{value.inspect}"
      Rails.logger.info "  - Value (as JSON): #{value.to_json rescue 'N/A'}"

      # If it's a hash, log its structure
      if value.is_a?(Hash)
        Rails.logger.info "  - Hash keys: #{value.keys.inspect}"
        value.each do |k, v|
          Rails.logger.info "    - [#{k.inspect}]: #{v.inspect} (class: #{v.class})"
        end
      end
    end

    # Log specific fields we're looking for
    Rails.logger.info "[GMAIL_PUBSUB] ========== SPECIFIC FIELDS =========="
    Rails.logger.info "[GMAIL_PUBSUB] params[:message]: #{params[:message].inspect}"
    Rails.logger.info "[GMAIL_PUBSUB] params[:subscription]: #{params[:subscription].inspect}"
    Rails.logger.info "[GMAIL_PUBSUB] params[:emailAddress]: #{params[:emailAddress].inspect}"
    Rails.logger.info "[GMAIL_PUBSUB] params[:email_address]: #{params[:email_address].inspect}"
    Rails.logger.info "[GMAIL_PUBSUB] params[:historyId]: #{params[:historyId].inspect}"
    Rails.logger.info "[GMAIL_PUBSUB] params[:history_id]: #{params[:history_id].inspect}"

    if params[:message].present?
      Rails.logger.info "[GMAIL_PUBSUB] params[:message][:data]: #{params[:message][:data].inspect}"
      Rails.logger.info "[GMAIL_PUBSUB] params[:message][:messageId]: #{params[:message][:messageId].inspect}"
      Rails.logger.info "[GMAIL_PUBSUB] params[:message][:publishTime]: #{params[:message][:publishTime].inspect}"
      Rails.logger.info "[GMAIL_PUBSUB] params[:message][:emailAddress]: #{params[:message][:emailAddress].inspect}"
      Rails.logger.info "[GMAIL_PUBSUB] params[:message][:historyId]: #{params[:message][:historyId].inspect}"
    end

    parsed_data = parse_pubsub_message
    Rails.logger.info "[GMAIL_PUBSUB] ========== PARSED RESULT =========="
    Rails.logger.info "[GMAIL_PUBSUB] Parsed data: #{parsed_data.inspect}"
    Rails.logger.info "[GMAIL_PUBSUB] Parsed data blank?: #{parsed_data.blank?}"
    Rails.logger.info "[GMAIL_PUBSUB] Parsed data has email_address?: #{parsed_data.present? && (parsed_data[:email_address] || parsed_data['email_address']).present?}"
    Rails.logger.info "[GMAIL_PUBSUB] Parsed data has history_id?: #{parsed_data.present? && (parsed_data[:history_id] || parsed_data['history_id']).present?}"
    Rails.logger.info "[GMAIL_PUBSUB] ============================================="

    # Acknowledge immediately to avoid timeout (must respond < 10s)
    render json: { status: 'received' }, status: :ok

    # Process asynchronously only if we have valid data
    if parsed_data.present? && (parsed_data[:email_address] || parsed_data['email_address']).present? && (parsed_data[:history_id] || parsed_data['history_id']).present?
      Rails.logger.info "[GMAIL_PUBSUB] Enqueuing ProcessPubsubNotificationJob with valid data"
      Gmail::ProcessPubsubNotificationJob.perform_later(parsed_data)
    else
      Rails.logger.warn "[GMAIL_PUBSUB] Skipping job enqueue - parsed_data is invalid or missing required fields"
      Rails.logger.warn "[GMAIL_PUBSUB] This may indicate a configuration issue with Google Pub/Sub webhook format"
    end
  rescue StandardError => e
    Rails.logger.error "[GMAIL_PUBSUB] Error receiving notification: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: 'Internal error' }, status: :ok # Still return 200 to avoid retry
  end

  private

  def parse_pubsub_message
    # Extract metadata from Pub/Sub headers
    message_id = request.headers['HTTP_X_GOOG_PUBSUB_MESSAGE_ID']
    publish_time = request.headers['HTTP_X_GOOG_PUBSUB_PUBLISH_TIME']
    subscription = request.headers['HTTP_X_GOOG_PUBSUB_SUBSCRIPTION_NAME'] || params[:subscription]

    Rails.logger.info "[GMAIL_PUBSUB] Pub/Sub headers - message_id: #{message_id.inspect}, publish_time: #{publish_time.inspect}, subscription: #{subscription.inspect}"

    # Priority 0: Parse raw body JSON directly (Rails might not auto-parse it)
    if @parsed_body_json.present?
      body_json = @parsed_body_json
      Rails.logger.info "[GMAIL_PUBSUB] Using pre-parsed body JSON: #{body_json.inspect}"

      # Try to extract from body JSON
      if body_json.is_a?(Hash)
        # Check for message wrapper
        if body_json['message'].present?
          message_data = body_json['message']
          decoded_data = parse_message_data(message_data)
          if decoded_data.present? && (decoded_data['emailAddress'] || decoded_data['email_address'] || decoded_data[:emailAddress] || decoded_data[:email_address])
            Rails.logger.info "[GMAIL_PUBSUB] Using body JSON (message wrapper)"
            return build_result(decoded_data, message_data, message_id, publish_time, subscription)
          end
        end

        # Check for direct fields in body
        if body_json['emailAddress'] || body_json['email_address'] || body_json['historyId'] || body_json['history_id']
          Rails.logger.info "[GMAIL_PUBSUB] Using body JSON (direct fields)"
          return build_result(body_json, body_json, message_id, publish_time, subscription)
        end
      end
    end

    # Priority 1: Handle unwrapped payload where JSON comes as a param key
    # (when "Enable payload unwrapping" is ON and "Write metadata" is OFF)
    json_key = params.keys.find { |key| key.start_with?('{') && (key.include?('emailAddress') || key.include?('email_address')) }
    if json_key.present?
      begin
        decoded_data = JSON.parse(json_key)
        Rails.logger.info "[GMAIL_PUBSUB] Using unwrapped payload (JSON as param key)"
        return build_result(decoded_data, {}, message_id, publish_time, subscription)
      rescue JSON::ParserError => e
        Rails.logger.warn "[GMAIL_PUBSUB] Failed to parse JSON key: #{e.message}"
      end
    end

    # Priority 2: Handle unwrapped payload at top level (when "Write metadata" is ON)
    # Check if emailAddress or historyId are directly in params
    if params[:emailAddress].present? || params[:email_address].present? || params[:historyId].present? || params[:history_id].present?
      Rails.logger.info "[GMAIL_PUBSUB] Using unwrapped payload (top level params)"
      return {
        email_address: params[:emailAddress] || params[:email_address],
        history_id: params[:historyId] || params[:history_id],
        message_id: params[:messageId] || params[:message_id] || message_id,
        publish_time: params[:publishTime] || params[:publish_time] || publish_time,
        subscription: subscription
      }
    end

    # Priority 3: Handle message wrapper (standard Pub/Sub format)
    message_data = params[:message]
    return {} if message_data.blank?

    decoded_data = parse_message_data(message_data)
    return {} if decoded_data.blank?

    build_result(decoded_data, message_data, message_id, publish_time, subscription)
  rescue JSON::ParserError, ArgumentError => e
    Rails.logger.error "[GMAIL_PUBSUB] Failed to parse message: #{e.message}"
    Rails.logger.error "[GMAIL_PUBSUB] Backtrace: #{e.backtrace.first(5).join("\n")}"
    {}
  end

  def parse_message_data(message_data)
    if message_data[:data].present? || message_data['data'].present?
      data = message_data[:data] || message_data['data']
      # Try to parse as JSON first (unwrapped payload)
      begin
        parsed = JSON.parse(data)
        Rails.logger.info "[GMAIL_PUBSUB] Using unwrapped payload (JSON in message.data)"
        return parsed
      rescue JSON::ParserError
        # If JSON parsing fails, try base64 decode (wrapped payload)
        begin
          decoded = Base64.decode64(data)
          parsed = JSON.parse(decoded)
          Rails.logger.info "[GMAIL_PUBSUB] Using wrapped payload (base64 decoded)"
          return parsed
        rescue ArgumentError, JSON::ParserError => e
          Rails.logger.warn "[GMAIL_PUBSUB] Failed to decode payload: #{e.message}"
          return {}
        end
      end
    elsif message_data[:emailAddress].present? || message_data[:email_address].present? || message_data['emailAddress'].present? || message_data['email_address'].present?
      # Payload already unwrapped and in message object
      Rails.logger.info "[GMAIL_PUBSUB] Using unwrapped payload (in message object)"
      return message_data
    else
      return {}
    end
  end

  def build_result(decoded_data, message_data, message_id, publish_time, subscription)
    {
      email_address: decoded_data['emailAddress'] || decoded_data[:emailAddress] || decoded_data['email_address'] || decoded_data[:email_address],
      history_id: decoded_data['historyId'] || decoded_data[:historyId] || decoded_data['history_id'] || decoded_data[:history_id],
      message_id: (message_data.is_a?(Hash) ? (message_data[:messageId] || message_data[:message_id] || message_data['messageId'] || message_data['message_id']) : nil) || decoded_data['messageId'] || decoded_data[:messageId] || message_id,
      publish_time: (message_data.is_a?(Hash) ? (message_data[:publishTime] || message_data[:publish_time] || message_data['publishTime'] || message_data['publish_time']) : nil) || decoded_data['publishTime'] || decoded_data[:publishTime] || publish_time,
      subscription: subscription
    }
  end
end
