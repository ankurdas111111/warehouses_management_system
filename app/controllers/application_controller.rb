class ApplicationController < ActionController::API
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
end
