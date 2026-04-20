class AgentBots::ResponseProcessor
  def initialize(agent_bot, payload)
    @agent_bot = agent_bot
    @payload = payload
  end

  def process(response)
    return unless response

    status_code = response.code.to_i
    Rails.logger.info "[AgentBot HTTP] Response Status: #{response.code} #{response.message}"

    if success_response?(status_code)
      handle_success_response(response)
    else
      handle_error_response(response)
    end
  end

  private

  def success_response?(status_code)
    status_code >= 200 && status_code < 300
  end

  def handle_success_response(response)
    Rails.logger.info "[AgentBot HTTP] Success: #{response.code}"

    begin
      parsed_response = JSON.parse(response.body)
      Rails.logger.info "[AgentBot HTTP] Parsed Response: #{parsed_response}"
      process_bot_response(parsed_response)
    rescue JSON::ParserError => e
      Rails.logger.error "[AgentBot HTTP] JSON parsing failed: #{e.message}"
    end
  end

  def handle_error_response(response)
    Rails.logger.error "[AgentBot HTTP] Error Response: #{response.code} - #{response.body}"
  end

  def process_bot_response(parsed_response)
    artifacts = extract_artifacts(parsed_response)
    return unless artifacts

    text_content = extract_text_from_artifacts(artifacts)
    return unless text_content

    conversation = AgentBots::ConversationFinder.new(@agent_bot, @payload).find_conversation
    return unless conversation

    # Check if text segmentation is enabled for this agent bot
    if @agent_bot.text_segmentation_enabled && ['evo_ai_provider', 'n8n_provider'].include?(@agent_bot.bot_provider)
      process_segmented_response(text_content, conversation)
    else
      # Process as a single message with signature
      final_content = build_message_with_signature(text_content)
      Rails.logger.info "[AgentBot HTTP] Bot Response Message: #{final_content}"
      
      # Try to create message normally first
      message_creator = AgentBots::MessageCreator.new(@agent_bot)
      message = message_creator.create_bot_reply(final_content, conversation)
      
      # If message creation failed (conversation not eligible, e.g., after transfer),
      # try to force create it anyway (for final responses after transfer)
      unless message
        Rails.logger.info "[AgentBot HTTP] Message creation failed (conversation not eligible), attempting force create..."
        message = message_creator.create_bot_reply(final_content, conversation, force: true)
      end
      
      message
    end
  end

  def extract_artifacts(parsed_response)
    artifacts = parsed_response.dig('result', 'artifacts')
    return unless artifacts&.any?

    artifacts
  end

  def extract_text_from_artifacts(artifacts)
    artifact = artifacts.first
    return unless artifact['parts']&.any?

    text_part = artifact['parts'].find { |p| p['type'] == 'text' }
    text_part&.dig('text')
  end

  def process_segmented_response(text_content, conversation)
    # Create segmentation service with bot's configuration
    segmentation_service = AgentBots::TextSegmentationService.new(
      @agent_bot.text_segmentation_limit || 300,
      @agent_bot.text_segmentation_min_size || 50
    )

    # Segment the text
    segments = segmentation_service.segment_text(text_content)

    Rails.logger.info "[AgentBot HTTP] Text segmented into #{segments.length} parts"
    segments.each_with_index do |segment, index|
      Rails.logger.info "[AgentBot HTTP] Segment #{index + 1}: #{segment[0..100]}#{'...' if segment.length > 100}"
    end

    # Create messages using the segmented message creator
    message_creator = AgentBots::SegmentedMessageCreator.new(@agent_bot)
    message_creator.create_messages(segments, conversation)
  end

  def build_message_with_signature(content)
    return content if @agent_bot.message_signature.blank?

    # Add signature at the top with two line breaks before the message
    "#{@agent_bot.message_signature}\n\n#{content}"
  end
end
