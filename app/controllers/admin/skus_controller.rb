module Admin
  class SkusController < BaseController
    def index
      @skus = Sku.order(:code)
    end
  end
end


