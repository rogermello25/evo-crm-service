class Whatsapp::EmbeddedSignupService
  include Rails.application.routes.url_helpers

  def initialize(account:, code:, business_id:, waba_id:, phone_number_id:, is_business_app_onboarding: false)
    @account = account
    @code = code
    @business_id = business_id
    @waba_id = waba_id
    @phone_number_id = phone_number_id
    @is_business_app_onboarding = is_business_app_onboarding
  end

  def perform
    validate_required_parameters!
    GlobalConfig.clear_cache

    access_token = exchange_code_for_token
    phone_info = fetch_phone_info_via_waba(@waba_id, @phone_number_id, access_token)
    validate_token_waba_access(access_token, @waba_id)

    waba_info = { waba_id: @waba_id, business_name: phone_info[:business_name] }

    # Only return channel data for inbox creation in controller
    build_channel_data(waba_info, phone_info, access_token)
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP] Embedded signup failed: #{e.message}")
    Rails.logger.error e.backtrace.first(3).join("\n")
    raise e
  end

  private

  def validate_required_parameters!
    missing_params = []
    missing_params << 'code' if @code.blank?
    missing_params << 'business_id' if @business_id.blank?
    missing_params << 'waba_id' if @waba_id.blank?
    missing_params << 'phone_number_id' if @phone_number_id.blank?

    return if missing_params.empty?

    raise ArgumentError, "Missing required parameters: #{missing_params.join(', ')}"
  end

  def whatsapp_api_version
    @whatsapp_api_version ||= GlobalConfigService.load('WHATSAPP_API_VERSION', 'v23.0')
  end

  def exchange_code_for_token
    Rails.logger.info '[WHATSAPP] Exchanging authorization code for access token'

    response = HTTParty.post(
      "https://graph.facebook.com/#{whatsapp_api_version}/oauth/access_token",
      headers: { 'Content-Type' => 'application/json' },
      body: {
        client_id: GlobalConfigService.load('WHATSAPP_APP_ID', ''),
        client_secret: GlobalConfigService.load('WHATSAPP_APP_SECRET', ''),
        code: @code,
        grant_type: 'authorization_code'
      }.to_json
    )

    unless response.success?
      Rails.logger.error "[WHATSAPP] Token exchange failed: #{response.code} - #{response.body}"
      raise StandardError, "Token exchange failed: #{response.body}"
    end

    data = response.parsed_response
    unless data['access_token']
      Rails.logger.error "[WHATSAPP] No access token in response: #{data}"
      raise StandardError, "No access token in response: #{data}"
    end

    Rails.logger.info '[WHATSAPP] Successfully exchanged code for access token'
    data['access_token']
  end

  def fetch_phone_info_via_waba(waba_id, phone_number_id, access_token)
    Rails.logger.info "[WHATSAPP] Fetching phone info for WABA: #{waba_id}, Phone: #{phone_number_id}"

    response = HTTParty.get(
      "https://graph.facebook.com/#{whatsapp_api_version}/#{waba_id}/phone_numbers",
      query: {
        access_token: access_token,
        fields: 'id,display_phone_number,verified_name,code_verification_status'
      }
    )

    unless response.success?
      Rails.logger.error "[WHATSAPP] Phone info fetch failed: #{response.code} - #{response.body}"
      raise StandardError, "WABA phone numbers fetch failed: #{response.body}"
    end

    data = response.parsed_response
    phone_numbers = data['data'] || []
    phone_data = phone_numbers.find { |phone| phone['id'] == phone_number_id } || phone_numbers.first

    if phone_data.nil?
      Rails.logger.error "[WHATSAPP] No phone numbers found for WABA #{waba_id}"
      raise StandardError, "No phone numbers found for WABA #{waba_id}"
    end

    display_phone_number = sanitize_phone_number(phone_data['display_phone_number'])

    Rails.logger.info "[WHATSAPP] Phone info retrieved: #{display_phone_number}"

    {
      phone_number_id: phone_data['id'],
      phone_number: "+#{display_phone_number}",
      verified: phone_data['code_verification_status'] == 'VERIFIED',
      business_name: phone_data['verified_name'] || phone_data['display_phone_number']
    }
  end

  def build_channel_data(waba_info, phone_info, access_token)
    check_existing_channel!(phone_info[:phone_number])

    {
      phone_number: phone_info[:phone_number],
      provider: 'whatsapp_cloud',
      provider_config: {
        api_key: access_token,
        access_token: access_token,  # Required for WhatsApp Cloud sync operations
        phone_number_id: phone_info[:phone_number_id],
        business_account_id: waba_info[:waba_id],
        webhook_verify_token: SecureRandom.hex(20),
        source: 'embedded_signup',
        is_business_app_onboarding: @is_business_app_onboarding  # Store the flag in provider_config
      },
      inbox_data: {
        name: "#{phone_info[:business_name]} WhatsApp",
        business_name: phone_info[:business_name]
      },
      setup_actions: {
        register_phone_number: !@is_business_app_onboarding,
        enable_sync_features: @is_business_app_onboarding,
        webhook_override_needed: true
      }
    }
  end

  def check_existing_channel!(phone_number)
    existing_channel = Channel::Whatsapp.find_by(account: @account, phone_number: phone_number)
    return unless existing_channel

    Rails.logger.error "[WHATSAPP] Channel already exists: #{existing_channel.phone_number}"
    raise StandardError, "Channel already exists for phone number: #{phone_number}"
  end

  def sanitize_phone_number(phone_number)
    return phone_number if phone_number.blank?

    phone_number.gsub(/[\s\-\(\)\.\+]/, '').strip
  end

  def validate_token_waba_access(access_token, waba_id)
    Rails.logger.info "[WHATSAPP] Validating token access to WABA: #{waba_id}"

    token_debug_data = fetch_token_debug_data(access_token)
    waba_scope = extract_waba_scope(token_debug_data)
    verify_waba_authorization(waba_scope, waba_id)

    Rails.logger.info '[WHATSAPP] Token validation successful'
  end

  def fetch_token_debug_data(access_token)
    response = HTTParty.get(
      "https://graph.facebook.com/#{whatsapp_api_version}/debug_token",
      query: {
        input_token: access_token,
        access_token: build_app_access_token
      }
    )

    unless response.success?
      Rails.logger.error "[WHATSAPP] Token validation failed: #{response.code} - #{response.body}"
      raise StandardError, "Token validation failed: #{response.body}"
    end

    response.parsed_response
  end

  def extract_waba_scope(token_data)
    granular_scopes = token_data.dig('data', 'granular_scopes')
    waba_scope = granular_scopes&.find { |scope| scope['scope'] == 'whatsapp_business_management' }

    raise StandardError, 'No WABA scope found in token' unless waba_scope

    waba_scope
  end

  def verify_waba_authorization(waba_scope, waba_id)
    authorized_waba_ids = waba_scope['target_ids'] || []

    return if authorized_waba_ids.include?(waba_id)

    Rails.logger.error "[WHATSAPP] Token does not have access to WABA #{waba_id}. Authorized: #{authorized_waba_ids}"
    raise StandardError, "Token does not have access to WABA #{waba_id}. Authorized WABAs: #{authorized_waba_ids}"
  end

  def build_app_access_token
    app_id = GlobalConfigService.load('WHATSAPP_APP_ID', '')
    app_secret = GlobalConfigService.load('WHATSAPP_APP_SECRET', '')
    "#{app_id}|#{app_secret}"
  end
end
