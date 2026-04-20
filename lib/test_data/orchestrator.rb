class TestData::Orchestrator
  class << self
    def call
      Rails.logger.info { '========== STARTING TEST DATA GENERATION ==========' }

      cleanup_existing_data

      Rails.logger.info { 'Starting to generate distributed test data...' }

      inboxes = TestData::InboxCreator.create_all
      target_messages = rand(TestData::Constants::MIN_MESSAGES..TestData::Constants::MAX_MESSAGES)
      avg_per_convo = rand(15..50)
      total_convos = (target_messages / avg_per_convo.to_f).ceil
      total_contacts = (total_convos / TestData::Constants::MAX_CONVERSATIONS_PER_CONTACT.to_f).ceil

      log_details(target_messages, total_contacts, total_convos)
      display_id_tracker = TestData::DisplayIdTracker.new

      Rails.logger.info { 'Starting data generation...' }
      generate_data(inboxes, total_contacts, target_messages, display_id_tracker)

      Rails.logger.info { '========== ALL DONE! Test data generated ==========' }
    end

    private

    # Simple value object to group generation parameters
    class DataGenerationParams
      attr_reader :inboxes, :total_contacts_needed, :target_message_count, :display_id_tracker

      def initialize(inboxes:, total_contacts_needed:, target_message_count:, display_id_tracker:)
        @inboxes = inboxes
        @total_contacts_needed = total_contacts_needed
        @target_message_count = target_message_count
        @display_id_tracker = display_id_tracker
      end
    end

    def cleanup_existing_data
      Rails.logger.info { 'Cleaning up existing test data...' }
      TestData::CleanupService.call
      Rails.logger.info { 'Cleanup complete' }
    end

    def generate_data(inboxes, total_contacts, target_messages, display_id_tracker)
      params = DataGenerationParams.new(
        inboxes: inboxes,
        total_contacts_needed: total_contacts,
        target_message_count: target_messages,
        display_id_tracker: display_id_tracker
      )

      generate_data_in_batches(params)
    end

    def generate_data_in_batches(params)
      contact_count = 0
      message_count = 0
      batch_number = 0

      while contact_count < params.total_contacts_needed
        batch_number += 1
        batch_size = [TestData::Constants::BATCH_SIZE, params.total_contacts_needed - contact_count].min
        Rails.logger.info { "Processing batch ##{batch_number} (#{batch_size} contacts)" }

        batch_service = TestData::ContactBatchService.new(
          inboxes: params.inboxes,
          batch_size: batch_size,
          display_id_tracker: params.display_id_tracker
        )
        batch_created_messages = batch_service.generate!

        contact_count += batch_size
        message_count += batch_created_messages
      end

      Rails.logger.info { "==> Completed with #{message_count} messages" }
    end

    def log_details(target_messages, total_contacts, total_convos)
      Rails.logger.info { "==> Plan: target of #{target_messages / 1_000_000.0}M messages" }
      Rails.logger.info { "    Planning for #{total_contacts} contacts and #{total_convos} conversations" }
    end
  end
end
