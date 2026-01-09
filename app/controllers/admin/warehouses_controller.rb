module Admin
  class WarehousesController < BaseController
    def index
      @warehouses = Warehouse.order(:code)
    end
  end
end


