# Service to check if a comment contains explicit words based on regex patterns
class Facebook::Moderation::ExplicitWordsChecker
  attr_reader :comment_content, :patterns

  def initialize(comment_content:, patterns: [])
    @comment_content = comment_content.to_s.downcase
    @patterns = patterns || []
  end

  def check
    return { found: false, matched_patterns: [] } if patterns.blank?
    return { found: false, matched_patterns: [] } if comment_content.blank?

    matched_patterns = []

    patterns.each do |pattern|
      next if pattern.blank?

      begin
        # Try to match as regex first
        regex = Regexp.new(pattern, Regexp::IGNORECASE)
        if regex.match?(comment_content)
          matched_patterns << pattern
        end
      rescue RegexpError => e
        Rails.logger.warn("Facebook::Moderation::ExplicitWordsChecker: Invalid regex pattern '#{pattern}': #{e.message}")
        # Fallback to simple string match if regex is invalid
        if comment_content.include?(pattern.downcase)
          matched_patterns << pattern
        end
      end
    end

    {
      found: matched_patterns.any?,
      matched_patterns: matched_patterns.uniq
    }
  rescue StandardError => e
    Rails.logger.error("Facebook::Moderation::ExplicitWordsChecker: Error checking explicit words: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    { found: false, matched_patterns: [] }
  end
end

