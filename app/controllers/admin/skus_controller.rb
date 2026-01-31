module Admin
  class SkusController < BaseController
    def index
      @q = params[:q].to_s.strip.presence
      @page = [ params[:page].to_i, 1 ].max
      @per = [ [ params[:per].to_i, 50 ].max, 200 ].min

      scope = Sku.order(:code)
      if @q.present?
        like = "%#{@q}%"
        scope = scope.where("code ILIKE ? OR name ILIKE ?", like, like)
      end
      @total = scope.count
      @skus = scope.limit(@per).offset((@page - 1) * @per).to_a
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
      AuditLog.record!(action: "admin.skus.update", auditable: @sku, metadata: { code: @sku.code })
      redirect_to admin_skus_path, notice: "SKU updated"
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_skus_path, alert: @sku.errors.full_messages.join(", ")
    rescue ArgumentError
      redirect_to admin_skus_path, alert: "Invalid price"
    end

    def destroy
      sku = Sku.find(params[:id])
      AuditLog.record!(action: "admin.skus.destroy", auditable: sku, metadata: { code: sku.code })
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
