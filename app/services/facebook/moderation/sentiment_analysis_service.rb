# Service to analyze sentiment of a Facebook comment using OpenAI
# Determines if the comment is offensive or inappropriate
class Facebook::Moderation::SentimentAnalysisService
  attr_reader :comment_content, :account

  def initialize(comment_content:, account:)
    @comment_content = comment_content.to_s
    @account = account
  end

  def analyze
    return { offensive: false, confidence: 0.0, reason: nil } if comment_content.blank?

    Rails.logger.info "[Facebook Moderation] SentimentAnalysisService: Analyzing comment: #{comment_content.inspect}"

    # Use OpenAI Global Processor Service for sentiment analysis
    result = call_openai_sentiment_analysis

    Rails.logger.info "[Facebook Moderation] SentimentAnalysisService: Raw result from OpenAI: #{result.inspect}"

    parsed_result = parse_sentiment_result(result)

    Rails.logger.info "[Facebook Moderation] SentimentAnalysisService: Parsed result: #{parsed_result.inspect}"

    parsed_result
  rescue StandardError => e
    Rails.logger.error("Facebook::Moderation::SentimentAnalysisService: Error analyzing sentiment: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    # Default to non-offensive on error to avoid false positives
    { offensive: false, confidence: 0.0, reason: "Error during analysis: #{e.message}" }
  end

  private

  def call_openai_sentiment_analysis
    # Create event payload for OpenAI service
    event = {
      'name' => 'analyze_sentiment',
      'data' => {
        'content' => comment_content
      }
    }

    Rails.logger.info "[Facebook Moderation] SentimentAnalysisService: Calling OpenAI with event: #{event.inspect}"

    service = Integrations::Openai::GlobalProcessorService.new(
      account: account,
      event: event
    )

    # Use perform method which handles analyze_sentiment correctly
    result = service.perform

    Rails.logger.info "[Facebook Moderation] SentimentAnalysisService: OpenAI perform result: #{result.inspect}"

    # perform returns { message: result.to_json } for analyze_sentiment
    # Extract and parse the JSON
    if result.is_a?(Hash) && result[:message].present?
      parsed = JSON.parse(result[:message])
      Rails.logger.info "[Facebook Moderation] SentimentAnalysisService: Parsed JSON from message: #{parsed.inspect}"
      parsed
    else
      Rails.logger.warn "[Facebook Moderation] SentimentAnalysisService: No message in result or result is not a Hash"
      nil
    end
  end

  def parse_sentiment_result(result)
    return { offensive: false, confidence: 0.0, reason: nil } unless result.present?

    # Result from perform is already parsed JSON: { offensive: ..., confidence: ..., reason: ... }
    if result.is_a?(Hash) && result.key?('offensive')
      # Already parsed JSON from perform
      {
        offensive: result['offensive'] == true,
        confidence: (result['confidence'] || 0.0).to_f,
        reason: result['reason']
      }
    elsif result.is_a?(Hash) && result.key?(:offensive)
      # Symbol keys
      {
        offensive: result[:offensive] == true,
        confidence: (result[:confidence] || 0.0).to_f,
        reason: result[:reason]
      }
    else
      { offensive: false, confidence: 0.0, reason: 'Unable to parse result' }
    end
  rescue StandardError => e
    Rails.logger.error("Facebook::Moderation::SentimentAnalysisService: Failed to parse result: #{e.message}")
    { offensive: false, confidence: 0.0, reason: 'Parse error' }
  end
end

