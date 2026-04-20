# frozen_string_literal: true

# Concern for sanitizing names to be compatible with external APIs
# Removes special characters and spaces, keeping only a-z, 0-9, and hyphens
module InstanceNameSanitizable
  extend ActiveSupport::Concern

  # Sanitizes a name to be compatible with external APIs
  # Only allows: a-z, 0-9, and hyphens
  # @param name [String] The original name
  # @return [String] The sanitized name
  def sanitize_instance_name(name)
    return '' if name.blank?

    name
      .downcase                                    # Convert to lowercase
      .gsub(/\s+/, '-')                            # Replace spaces with hyphens
      .gsub(/[^a-z0-9-]/, '').squeeze('-')         # Remove special chars and squeeze hyphens
      .gsub(/^-|-$/, '')                           # Remove leading/trailing hyphens
  end
end

