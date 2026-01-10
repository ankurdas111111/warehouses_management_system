module Web
  class BaseController < ActionController::Base
    protect_from_forgery with: :exception
    layout "application"

    before_action :load_current_user_from_cookie
    helper_method :indian_cities

    private

    def indian_cities
      IndianCities::CITIES
    end

    def load_current_user_from_cookie
      token = cookies.encrypted[:jwt]
      return Current.user = nil if token.blank?

      payload = JwtToken.decode(token)
      Current.user = User.find_by(id: payload["sub"])
    rescue JwtToken::DecodeError
      cookies.delete(:jwt)
      Current.user = nil
    end
  end
end


