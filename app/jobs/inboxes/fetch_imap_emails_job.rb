require 'net/imap'

# Ensure EvolutionExceptionTracker is loaded
require Rails.root.join('lib', 'evolution_exception_tracker').to_s

class Inboxes::FetchImapEmailsJob < MutexApplicationJob
  queue_as :scheduled_jobs

  def perform(channel, interval = 1)
    return unless should_fetch_email?(channel)

    key = format(::Redis::Alfred::EMAIL_MESSAGE_MUTEX, inbox_id: channel.inbox.id)

    # Timeout maior para inboxes de alto volume
    timeout = determine_lock_timeout(channel)

    with_lock(key, timeout) do
      process_email_for_channel(channel, interval)
    end
  rescue *ExceptionList::IMAP_EXCEPTIONS => e
    Rails.logger.error "Authorization error for email channel - #{channel.inbox.id} : #{e.message}"
  rescue EOFError, OpenSSL::SSL::SSLError, Net::IMAP::NoResponseError, Net::IMAP::BadResponseError, Net::IMAP::InvalidResponseError => e
    Rails.logger.error "Error for email channel - #{channel.inbox.id} : #{e.message}"
  rescue LockAcquisitionError
    Rails.logger.error "Lock failed for #{channel.inbox.id}"
  rescue StandardError => e
    EvolutionExceptionTracker.new(e, account: nil).capture_exception
  end

  private

  def should_fetch_email?(channel)
    return false if channel.reauthorization_required?
    return false if channel.use_push_notifications? # Skip IMAP if push is enabled

    channel.imap_enabled?
  end

  def determine_lock_timeout(channel)
    # Para inboxes de alto volume (Gmail corporativo), usar timeout maior
    if high_volume_inbox?(channel)
      30.minutes
    else
      5.minutes
    end
  end

  def high_volume_inbox?(channel)
    # Considerar alto volume se NÃO for Gmail pessoal
    # Gmail corporativo/empresarial geralmente tem muito mais volume
    return false unless channel.google?

    email_domain = channel.email.split('@').last
    !['gmail.com', 'googlemail.com'].include?(email_domain)
  end

  def process_email_for_channel(channel, interval)
    start_time = Time.current

    inbound_emails = if channel.microsoft?
                       Imap::MicrosoftFetchEmailService.new(channel: channel, interval: interval).perform
                     elsif channel.google?
                       Imap::GoogleFetchEmailService.new(channel: channel, interval: interval).perform
                     else
                       Imap::FetchEmailService.new(channel: channel, interval: interval).perform
                     end

    fetch_duration = Time.current - start_time
    log_fetch_metrics(channel, inbound_emails.length, fetch_duration)

    # Para alto volume, processar assincronamente em lotes
    if high_volume_inbox?(channel) && inbound_emails.length > 50
      process_emails_asynchronously(channel, inbound_emails)
    else
      # Processamento síncrono para baixo volume
      processed_emails = inbound_emails.map do |inbound_mail|
        process_mail(inbound_mail, channel)
      end

      total_duration = Time.current - start_time
      log_processing_metrics(channel, inbound_emails.length, processed_emails.compact.length, total_duration)
      processed_emails
    end
  rescue OAuth2::Error => e
    Rails.logger.error "Error for email channel - #{channel.inbox.id} : #{e.message}"
    channel.authorization_error!
  end

  def process_emails_asynchronously(channel, inbound_emails)
    Rails.logger.info "[ASYNC_PROCESSING] Queueing #{inbound_emails.length} emails in batches for inbox #{channel.inbox.id}"

    # Processar em lotes de 20 emails
    batch_size = 20
    batches_queued = 0

    inbound_emails.each_slice(batch_size) do |email_batch|
      Inboxes::ProcessEmailBatchJob.perform_later(channel, email_batch)
      batches_queued += 1
    end

    Rails.logger.info "[ASYNC_PROCESSING] Queued #{batches_queued} batches for processing"
    []  # Retornar array vazio pois processamento é assíncrono
  end

  def process_mail(inbound_mail, channel)
    Imap::ImapMailbox.new.process(inbound_mail, channel)
  rescue StandardError => e
    EvolutionExceptionTracker.new(e, account: nil).capture_exception
    Rails.logger.error("
      #{channel.provider} Email dropped: #{inbound_mail.from} and message_source_id: #{inbound_mail.message_id}")
    nil  # Retornar nil para indicar falha no processamento
  end

  def log_fetch_metrics(channel, emails_found, fetch_duration)
    Rails.logger.info "[EMAIL_METRICS] Inbox: #{channel.inbox.id} | Found: #{emails_found} emails | Fetch Duration: #{(fetch_duration * 1000).round(2)}ms | Rate: #{(emails_found / fetch_duration).round(2)} emails/sec"

    # Alertar se a busca demorou muito
    if fetch_duration > 30.seconds
      Rails.logger.warn "[EMAIL_ALERT] Slow fetch detected for inbox #{channel.inbox.id}: #{fetch_duration.round(2)}s"
    end
  end

  def log_processing_metrics(channel, emails_found, emails_processed, total_duration)
    success_rate = emails_found > 0 ? (emails_processed.to_f / emails_found * 100).round(2) : 0

    Rails.logger.info "[EMAIL_METRICS] Inbox: #{channel.inbox.id} | Found: #{emails_found} | Processed: #{emails_processed} | Success Rate: #{success_rate}% | Total Duration: #{(total_duration * 1000).round(2)}ms"

    # Alertar se a taxa de sucesso for baixa
    if emails_found > 10 && success_rate < 80
      Rails.logger.warn "[EMAIL_ALERT] Low success rate for inbox #{channel.inbox.id}: #{success_rate}%"
    end

    # Alertar se o processamento total demorou muito
    if total_duration > 60.seconds
      Rails.logger.warn "[EMAIL_ALERT] Slow processing detected for inbox #{channel.inbox.id}: #{total_duration.round(2)}s"
    end
  end
end
