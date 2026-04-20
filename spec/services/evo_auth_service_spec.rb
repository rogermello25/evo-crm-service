require 'rails_helper'
require 'webmock/rspec'

RSpec.describe EvoAuthService do
  let(:base_url) { 'http://auth.test' }
  let(:service) { described_class.new(base_url) }
  let(:endpoint) { "#{base_url}/api/v1/auth/validate" }

  before do
    Current.bearer_token = nil
    Current.api_access_token = nil
  end

  describe '#validate_token' do
    it 'returns validated payload when auth-service responds with success' do
      stub_request(:post, endpoint)
        .with(headers: { 'Authorization' => 'Bearer valid-token' })
        .to_return(
          status: 200,
          body: {
            success: true,
            data: {
              user: { id: 'u-1', email: 'user@example.com' },
              accounts: [{ id: 'a-1' }]
            }
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = service.validate_token(token: 'valid-token', token_type: :bearer)

      expect(result).to include('user', 'accounts')
      expect(result.dig('user', 'email')).to eq('user@example.com')
    end

    it 'maps auth-service unauthorized response to validation error with code' do
      stub_request(:post, endpoint)
        .with(headers: { 'Authorization' => 'Bearer invalid-token' })
        .to_return(
          status: 401,
          body: {
            success: false,
            error: {
              code: 'INVALID_TOKEN',
              message: 'Invalid bearer token'
            }
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect do
        service.validate_token(token: 'invalid-token', token_type: :bearer)
      end.to raise_error(EvoAuthService::ValidationError) { |error|
        expect(error.code).to eq('INVALID_TOKEN')
        expect(error.message).to eq('Invalid bearer token')
      }
    end

    it 'maps missing code for forbidden response to FORBIDDEN' do
      stub_request(:post, endpoint)
        .with(headers: { 'Authorization' => 'Bearer invalid-token' })
        .to_return(
          status: 403,
          body: {
            success: false,
            error: {
              message: 'Access denied'
            }
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect do
        service.validate_token(token: 'invalid-token', token_type: :bearer)
      end.to raise_error(EvoAuthService::ValidationError) { |error|
        expect(error.code).to eq(ApiErrorCodes::FORBIDDEN)
        expect(error.status).to eq(403)
      }
    end

    it 'maps missing code for unprocessable response to VALIDATION_ERROR' do
      stub_request(:post, endpoint)
        .with(headers: { 'Authorization' => 'Bearer invalid-token' })
        .to_return(
          status: 422,
          body: {
            success: false,
            error: {
              message: 'Invalid payload'
            }
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect do
        service.validate_token(token: 'invalid-token', token_type: :bearer)
      end.to raise_error(EvoAuthService::ValidationError) { |error|
        expect(error.code).to eq(ApiErrorCodes::VALIDATION_ERROR)
        expect(error.status).to eq(422)
      }
    end

    it 'maps upstream server failures to authentication service error' do
      stub_request(:post, endpoint)
        .with(headers: { 'Authorization' => 'Bearer valid-token' })
        .to_return(status: 500, body: { error: { message: 'Internal error' } }.to_json)

      expect do
        service.validate_token(token: 'valid-token', token_type: :bearer)
      end.to raise_error(EvoAuthService::AuthenticationError, 'Authentication service unavailable')
    end

    it 'maps malformed success payload to authentication service error' do
      stub_request(:post, endpoint)
        .with(headers: { 'Authorization' => 'Bearer valid-token' })
        .to_return(status: 200, body: '{invalid-json', headers: { 'Content-Type' => 'application/json' })

      expect do
        service.validate_token(token: 'valid-token', token_type: :bearer)
      end.to raise_error(EvoAuthService::AuthenticationError, 'Authentication service unavailable')
    end

    it 'maps blank success payload to authentication service error' do
      stub_request(:post, endpoint)
        .with(headers: { 'Authorization' => 'Bearer valid-token' })
        .to_return(status: 200, body: '', headers: { 'Content-Type' => 'application/json' })

      expect do
        service.validate_token(token: 'valid-token', token_type: :bearer)
      end.to raise_error(EvoAuthService::AuthenticationError, 'Authentication service unavailable')
    end
  end
end
