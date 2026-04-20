# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'CustomAttributeDefinition enum mapping' do
  it 'defines datetime display type mapped to 8' do
    source = File.read(File.expand_path('../../app/models/custom_attribute_definition.rb', __dir__))

    expect(source).to match(/enum\s+attribute_display_type:\s*\{[^}]*datetime:\s*8[^}]*\}/m)
  end
end
