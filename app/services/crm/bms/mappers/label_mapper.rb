class Crm::Bms::Mappers::LabelMapper
  def self.map(label)
    new(label).map
  end

  def initialize(label)
    @label = label
  end

  def map
    {
      name: label.name,
      description: build_description
    }
  end

  private

  attr_reader :label

  def build_description
    # ActsAsTaggableOn::Tag only has 'name' field, no description
    "Label created from Evolution: #{label.name}"
  end
end
