# == Schema Information
#
# This is a conceptual model for service tokens.
# For now, we're using environment variables for simplicity,
# but this model can be used for future database-backed token management.
#
class ServiceToken
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :token, :string
  attribute :description, :string
  attribute :active, :boolean, default: true

  # For now, we'll use environment variables
  # Future: store in database for better management
  def self.find_by_token(token)
    return nil if token.blank?
    
    valid_token = ENV['EVOAI_CRM_API_TOKEN']
    return nil if valid_token.blank?
    
    if ActiveSupport::SecurityUtils.secure_compare(valid_token, token)
      new(
        name: 'evoai_crm_service_token',
        token: token,
        description: 'Internal service-to-service communication token',
        active: true
      )
    else
      nil
    end
  end

  def self.valid?(token)
    find_by_token(token).present?
  end

  def valid?
    active && token.present?
  end

  # Future methods for database-backed implementation
  # 
  # def self.generate_token
  #   SecureRandom.hex(32)
  # end
  #
  # def regenerate!
  #   self.token = self.class.generate_token
  #   save!
  # end
end