# frozen_string_literal: true

begin
  require 'rails_helper'
rescue LoadError
  RSpec.describe Dashboard::FiltersBuilder do
    it 'has service spec scaffold ready' do
      skip 'rails_helper is not available in this workspace snapshot'
    end
  end
end

return unless defined?(Rails)

RSpec.describe Dashboard::FiltersBuilder do
  describe '#time_range' do
    it 'uses 30 days default window when since/until are absent' do
      range = described_class.new(params: {}).time_range
      expect(range.begin).to be <= 29.days.ago.end_of_day
      expect(range.end).to be >= Time.current.beginning_of_day
    end

    it 'parses unix timestamps for since/until' do
      since = 7.days.ago.to_i
      until_time = Time.current.to_i
      range = described_class.new(params: { since: since, until: until_time }).time_range

      expect(range.begin.to_i).to be <= since
      expect(range.end.to_i).to be >= until_time
    end

    it 'normalizes inverted intervals by swapping bounds' do
      since = Time.current.to_i
      until_time = 7.days.ago.to_i
      range = described_class.new(params: { since: since, until: until_time }).time_range

      expect(range.begin).to be <= range.end
    end
  end
end
