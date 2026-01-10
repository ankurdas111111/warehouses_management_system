module Admin
  class SkusController < BaseController
    def index
      @skus = Sku.order(:code)
    end

    def destroy
      sku = Sku.find(params[:id])
      sku.destroy!
      redirect_to admin_skus_path, notice: "SKU deleted"
    rescue ActiveRecord::DeleteRestrictionError => e
      redirect_to admin_skus_path, alert: e.message
    end

    private

  end
end


