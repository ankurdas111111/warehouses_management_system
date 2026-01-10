module Web
  class HomeController < BaseController
    def index
      if Current.user.present?
        redirect_to new_order_path
      else
        redirect_to login_path
      end
    end
  end
end


