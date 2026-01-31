class SkusController < ApplicationController
  def index
    skus = Sku.order(:id)
    render json: skus.map { |s| { id: s.id, code: s.code, name: s.name } }
  end

  def create
    p = params.permit(:code, :name).to_h.deep_symbolize_keys
    sku = Sku.create!(code: p[:code], name: p[:name])
    render json: { id: sku.id, code: sku.code, name: sku.name }, status: :created
  end
end
