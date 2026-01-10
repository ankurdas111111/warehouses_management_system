module Admin
  class WarehousesController < BaseController
    def index
      @location = params[:location].to_s.strip.presence
      scope = Warehouse.order(:code)
      scope = scope.where(location: @location) if @location.present?
      @warehouses = scope.to_a
    end

    def new
      @warehouse = Warehouse.new
    end

    def create
      @warehouse = Warehouse.new(warehouse_params)
      @warehouse.save!
      redirect_to admin_warehouses_path, notice: "Warehouse created"
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def edit
      @warehouse = Warehouse.find(params[:id])
    end

    def update
      @warehouse = Warehouse.find(params[:id])
      @warehouse.update!(warehouse_params)
      redirect_to admin_warehouses_path, notice: "Warehouse updated"
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def destroy
      warehouse = Warehouse.find(params[:id])
      warehouse.destroy!
      redirect_to admin_warehouses_path, notice: "Warehouse deleted"
    rescue ActiveRecord::DeleteRestrictionError => e
      redirect_to admin_warehouses_path, alert: e.message
    end

    private

    def warehouse_params
      params.require(:warehouse).permit(:code, :name, :location)
    end
  end
end


