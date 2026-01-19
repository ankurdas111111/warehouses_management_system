module Admin
  class WarehousesController < BaseController
    def index
      @location = params[:location].to_s.strip.presence
      @q = params[:q].to_s.strip.presence
      @page = [params[:page].to_i, 1].max
      @per = [[params[:per].to_i, 50].max, 200].min

      scope = Warehouse.order(:code)
      scope = scope.where(location: @location) if @location.present?
      if @q.present?
        like = "%#{@q}%"
        scope = scope.where("code ILIKE ? OR name ILIKE ? OR location ILIKE ?", like, like, like)
      end
      @total = scope.count
      @warehouses = scope.limit(@per).offset((@page - 1) * @per).to_a
    end

    def new
      @warehouse = Warehouse.new
    end

    def create
      @warehouse = Warehouse.new(warehouse_params)
      @warehouse.save!
      AuditLog.record!(action: "admin.warehouses.create", auditable: @warehouse, metadata: { code: @warehouse.code })
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
      AuditLog.record!(action: "admin.warehouses.update", auditable: @warehouse, metadata: { code: @warehouse.code })
      redirect_to admin_warehouses_path, notice: "Warehouse updated"
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def destroy
      warehouse = Warehouse.find(params[:id])
      AuditLog.record!(action: "admin.warehouses.destroy", auditable: warehouse, metadata: { code: warehouse.code })
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


