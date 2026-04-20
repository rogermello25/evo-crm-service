require 'rails_helper'

RSpec.describe Api::V1::GlobalConfigController, type: :controller do
  before do
    # Stub with empty/default values to avoid DB dependency while preserving realistic behavior
    allow(GlobalConfigService).to receive(:load).and_wrap_original do |_method, key, default|
      default
    end
  end

  describe 'GET #show' do
    it 'returns public config without authentication' do
      get :show, format: :json
      expect(response).to have_http_status(:ok)
    end

    it 'includes all expected top-level keys' do
      get :show, format: :json
      json = JSON.parse(response.body)

      expected_keys = %w[
        fbAppId fbApiVersion wpAppId wpApiVersion wpWhatsappConfigId
        instagramAppId googleOAuthClientId azureAppId
        hasEvolutionConfig hasEvolutionGoConfig openaiConfigured
        enableAccountSignup recaptchaSiteKey clarityProjectId
      ]

      expected_keys.each do |key|
        expect(json).to have_key(key), "Expected response to include key '#{key}'"
      end
    end

    it 'includes recaptchaSiteKey in the response' do
      allow(GlobalConfigService).to receive(:load).with('RECAPTCHA_SITE_KEY', nil).and_return('6Lc_test_key')

      get :show, format: :json
      json = JSON.parse(response.body)
      expect(json['recaptchaSiteKey']).to eq('6Lc_test_key')
    end

    it 'includes clarityProjectId in the response' do
      allow(GlobalConfigService).to receive(:load).with('CLARITY_PROJECT_ID', nil).and_return('clarity_test_id')

      get :show, format: :json
      json = JSON.parse(response.body)
      expect(json['clarityProjectId']).to eq('clarity_test_id')
    end

    it 'returns nil for unconfigured recaptchaSiteKey' do
      get :show, format: :json
      json = JSON.parse(response.body)
      expect(json['recaptchaSiteKey']).to be_nil
    end

    it 'returns nil for unconfigured clarityProjectId' do
      get :show, format: :json
      json = JSON.parse(response.body)
      expect(json['clarityProjectId']).to be_nil
    end

    context 'boolean flags' do
      it 'returns hasEvolutionConfig true when API URL and secret are configured' do
        allow(GlobalConfigService).to receive(:load).with('EVOLUTION_API_URL', '').and_return('https://evo.example.com')
        allow(GlobalConfigService).to receive(:load).with('EVOLUTION_ADMIN_SECRET', '').and_return('secret123')

        get :show, format: :json
        json = JSON.parse(response.body)
        expect(json['hasEvolutionConfig']).to be true
      end

      it 'returns hasEvolutionConfig false when API URL or secret is missing' do
        allow(GlobalConfigService).to receive(:load).with('EVOLUTION_API_URL', '').and_return('https://evo.example.com')
        allow(GlobalConfigService).to receive(:load).with('EVOLUTION_ADMIN_SECRET', '').and_return('')

        get :show, format: :json
        json = JSON.parse(response.body)
        expect(json['hasEvolutionConfig']).to be false
      end

      it 'returns hasEvolutionGoConfig true when API URL and secret are configured' do
        allow(GlobalConfigService).to receive(:load).with('EVOLUTION_GO_API_URL', '').and_return('https://evogo.example.com')
        allow(GlobalConfigService).to receive(:load).with('EVOLUTION_GO_ADMIN_SECRET', '').and_return('secret456')

        get :show, format: :json
        json = JSON.parse(response.body)
        expect(json['hasEvolutionGoConfig']).to be true
      end

      it 'returns openaiConfigured true when URL, key and model are all set' do
        allow(GlobalConfigService).to receive(:load).with('OPENAI_API_URL', '').and_return('https://api.openai.com')
        allow(GlobalConfigService).to receive(:load).with('OPENAI_API_SECRET', '').and_return('sk-test')
        allow(GlobalConfigService).to receive(:load).with('OPENAI_MODEL', '').and_return('gpt-4')

        get :show, format: :json
        json = JSON.parse(response.body)
        expect(json['openaiConfigured']).to be true
      end

      it 'returns openaiConfigured false when any OpenAI field is missing' do
        allow(GlobalConfigService).to receive(:load).with('OPENAI_API_URL', '').and_return('https://api.openai.com')
        allow(GlobalConfigService).to receive(:load).with('OPENAI_API_SECRET', '').and_return('')
        allow(GlobalConfigService).to receive(:load).with('OPENAI_MODEL', '').and_return('gpt-4')

        get :show, format: :json
        json = JSON.parse(response.body)
        expect(json['openaiConfigured']).to be false
      end

      it 'returns hasEvolutionGoConfig false when API URL or secret is missing' do
        allow(GlobalConfigService).to receive(:load).with('EVOLUTION_GO_API_URL', '').and_return('https://evogo.example.com')
        allow(GlobalConfigService).to receive(:load).with('EVOLUTION_GO_ADMIN_SECRET', '').and_return('')

        get :show, format: :json
        json = JSON.parse(response.body)
        expect(json['hasEvolutionGoConfig']).to be false
      end

      it 'returns enableAccountSignup true when configured' do
        allow(GlobalConfigService).to receive(:load).with('ENABLE_ACCOUNT_SIGNUP', 'false').and_return('true')

        get :show, format: :json
        json = JSON.parse(response.body)
        expect(json['enableAccountSignup']).to be true
      end

      it 'returns enableAccountSignup false by default' do
        get :show, format: :json
        json = JSON.parse(response.body)
        expect(json['enableAccountSignup']).to be false
      end
    end
  end
end
