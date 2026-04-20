# frozen_string_literal: true

# Configure ActiveStorage for development environment
Rails.application.configure do
  # Skip SSL verification for S3-compatible services in development
  # This fixes SSL certificate verification issues with Cloudflare R2 in local development
  if Rails.env.development?
    require 'aws-sdk-s3'

    Aws.config.update(
      ssl_verify_peer: false,
      http_wire_trace: false  # Desabilitar trace HTTP para não poluir logs com dados binários
    )

    Rails.logger.info "🔓 ActiveStorage: SSL verification disabled for development environment"
  end
end
