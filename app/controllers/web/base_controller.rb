module Web
  class BaseController < ActionController::Base
    protect_from_forgery with: :exception
    layout "application"

    before_action :load_current_user_from_cookie
    before_action :set_current_request_context
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

    def set_current_request_context
      Current.request_id = request.request_id
      Current.request_path = request.fullpath
      Current.request_method = request.request_method
      Current.ip = request.remote_ip
    end
  end
end
