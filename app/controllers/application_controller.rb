class ApplicationController < ActionController::API
  before_action :set_current_request_context

  rescue_from Orders::ValidationError do |e|
    render json: { error: e.message }, status: :unprocessable_entity
  end

  rescue_from Orders::OutOfStockError do |e|
    render json: { error: e.message }, status: :conflict
  end

  rescue_from Orders::InvalidTransitionError do |e|
    render json: { error: e.message }, status: :conflict
  end

  rescue_from ActiveRecord::RecordNotFound do |e|
    render json: { error: e.message }, status: :not_found
  end

  rescue_from Inventory::ValidationError do |e|
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_current_request_context
    Current.request_id = request.request_id
    Current.request_path = request.fullpath
    Current.request_method = request.request_method
    Current.ip = request.remote_ip
  end
end
