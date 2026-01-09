class WarehousesController < ApplicationController
  def index
    warehouses = Warehouse.order(:id)
    render json: warehouses.map { |w| { id: w.id, code: w.code, name: w.name, location: w.location } }
  end

  def create
    p = params.permit(:code, :name, :location).to_h.deep_symbolize_keys
    wh = Warehouse.create!(code: p[:code], name: p[:name], location: p[:location])
    render json: { id: wh.id, code: wh.code, name: wh.name, location: wh.location }, status: :created
  end
end


