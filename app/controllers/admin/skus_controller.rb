module Admin
  class SkusController < BaseController
    def index
      @skus = Sku.order(:code)
    end

    def update
      @sku = Sku.find(params[:id])
      attrs = sku_params
      if attrs.key?(:price_inr)
        inr = attrs.delete(:price_inr).to_s.strip
        paise = (BigDecimal(inr) * 100).to_i
        attrs[:price_cents] = paise
      end
      @sku.update!(attrs)
      redirect_to admin_skus_path, notice: "SKU updated"
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_skus_path, alert: @sku.errors.full_messages.join(", ")
    rescue ArgumentError
      redirect_to admin_skus_path, alert: "Invalid price"
    end

    def destroy
      sku = Sku.find(params[:id])
      sku.destroy!
      redirect_to admin_skus_path, notice: "SKU deleted"
    rescue ActiveRecord::DeleteRestrictionError => e
      redirect_to admin_skus_path, alert: e.message
    end

    private

    def sku_params
      params.require(:sku).permit(:code, :name, :price_inr)
    end

  end
end


