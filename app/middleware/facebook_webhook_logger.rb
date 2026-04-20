# Middleware to intercept Facebook webhook requests to /bot
# Logs the payload and processes feed events before the facebook-messenger gem processes messaging events
class FacebookWebhookLogger
  def initialize(app)
    @app = app
  end

  def call(env)
    # Only process POST requests to /bot (Facebook webhook endpoint)
    if env['REQUEST_METHOD'] == 'POST' && env['PATH_INFO'] == '/bot'
      # Read the raw body from the input stream
      input = env['rack.input']
      raw_body = input.read

      # Rewind the input stream so the next middleware can read it
      input.rewind

      begin
        payload = JSON.parse(raw_body)

        # Log the full payload structure
        Rails.logger.info("=" * 80)
        Rails.logger.info("Facebook Webhook Received - POST /bot")
        Rails.logger.info("Payload object: #{payload['object']}")
        Rails.logger.info("Number of entries: #{payload['entry']&.length || 0}")

        # Log each entry
        if payload['entry'].present?
          payload['entry'].each_with_index do |entry, idx|
            page_id = entry['id']
            Rails.logger.info("Entry #{idx + 1}:")
            Rails.logger.info("  Page ID: #{page_id}")
            Rails.logger.info("  Has messaging events: #{entry['messaging'].present?}")
            Rails.logger.info("  Has changes (feed): #{entry['changes'].present?}")

            # Log messaging events count
            if entry['messaging'].present?
              Rails.logger.info("  Messaging events count: #{entry['messaging'].length}")
              entry['messaging'].each_with_index do |msg, msg_idx|
                Rails.logger.info("    Messaging[#{msg_idx}]: #{msg.keys.join(', ')}")
              end
            end

            # Log feed changes count
            if entry['changes'].present?
              Rails.logger.info("  Feed changes count: #{entry['changes'].length}")
              entry['changes'].each_with_index do |change, change_idx|
                field = change['field']
                verb = change['value']&.dig('verb')
                item = change['value']&.dig('item')
                Rails.logger.info("    Change[#{change_idx}]: field=#{field}, verb=#{verb}, item=#{item}")

                # Log full change value for comments to debug message content
                if field == 'feed' && item == 'comment'
                  change_value = change['value']
                  Rails.logger.info("    Comment payload keys: #{change_value.keys.join(', ')}")
                  Rails.logger.info("    Comment message: #{change_value['message'].inspect}")
                  Rails.logger.info("    Comment full payload: #{change_value.to_json}")
                end

                # Process feed changes
                if field == 'feed'
                  Rails.logger.info("    → Processing feed change: #{verb}")
                  process_feed_change(change['value'], page_id)
                end
              end
            end
          end
        end

        Rails.logger.info("=" * 80)
      rescue JSON::ParserError => e
        Rails.logger.warn("FacebookWebhookLogger: Failed to parse webhook payload: #{e.message}")
      rescue StandardError => e
        Rails.logger.error("FacebookWebhookLogger: Error processing webhook: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n"))
      end
    end

    # Continue with the request
    @app.call(env)
  end

  private

  def process_feed_change(change_value, page_id)
    return unless change_value.present?

    Rails.logger.info("FacebookWebhookLogger: Enqueuing feed event job for page #{page_id}")
    Webhooks::FacebookFeedEventsJob.perform_later(change_value, page_id: page_id)
  rescue StandardError => e
    Rails.logger.error("FacebookWebhookLogger: Failed to enqueue feed event job: #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
  end
end

