# frozen_string_literal: true

class Public::Api::V1::LeadsController < Public::Api::V1::BaseController
  def create
    service_result = Public::Leads::CreationService.new(
      account: @account,
      lead_params: permitted_params
    ).perform

    if service_result[:success]
      render json: {
        success: true,
        lead_id: service_result[:contact].id,
        deal_id: service_result[:pipeline_item].id,
        message: 'Lead created successfully'
      }, status: :created
    else
      render_unprocessable_entity(service_result[:errors] || [service_result[:error]])
    end
  rescue StandardError => e
    Rails.logger.error "Public Leads API: Error creating lead - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      success: false,
      error: 'Internal server error',
      message: 'An unexpected error occurred while creating the lead'
    }, status: :internal_server_error
  end

  private

  def permitted_params
    params.permit(
      contact: [:name, :email, :phone_number, :company],
      deal: [:title, :value, :pipeline_id, :stage_id],
      custom_fields: {},
      metadata: {}
    )
  end
end

