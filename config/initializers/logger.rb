# frozen_string_literal: true

# Wrap Rails.logger with ActiveSupport::TaggedLogging so callers can emit
# structured context tags, e.g.:
#
#   Rails.logger.tagged('[WebSocket]') { Rails.logger.info 'connected' }
#   CrmLogger.websocket.info 'Client subscribed'
#   CrmLogger.automation.warn 'Condition skipped'
#   CrmLogger.slack.error 'Send failed'
#
unless Rails.logger.respond_to?(:tagged)
  Rails.logger = ActiveSupport::TaggedLogging.new(Rails.logger)
end

module CrmLogger
  SUBSYSTEMS = %w[WebSocket Automation Slack MCP OAuth Knowledge BotRuntime].freeze

  SUBSYSTEMS.each do |subsystem|
    define_singleton_method(subsystem.gsub(/[^a-z]/i, '_').downcase) do
      TaggedProxy.new(Rails.logger, "[#{subsystem}]")
    end
  end

  class TaggedProxy
    def initialize(logger, tag)
      @logger = logger
      @tag = tag
    end

    %i[debug info warn error fatal].each do |level|
      define_method(level) do |message = nil, &block|
        @logger.tagged(@tag) { @logger.public_send(level, message, &block) }
      end
    end
  end
end
