module UiAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user
    before_action :authenticate_ui_user!
  end

  def authenticate_ui_user!
    token = cookies.encrypted[:jwt]
    if token.blank?
      Current.user = nil
      redirect_to login_path, alert: "Please log in."
      return
    end

    payload = JwtToken.decode(token)
    user = User.find_by(id: payload["sub"])
    raise JwtToken::DecodeError, "user not found" unless user
    Current.user = user
  rescue JwtToken::DecodeError
    cookies.delete(:jwt)
    Current.user = nil
    redirect_to login_path, alert: "Session expired. Please log in again."
  end

  def current_user
    Current.user
  end
end


