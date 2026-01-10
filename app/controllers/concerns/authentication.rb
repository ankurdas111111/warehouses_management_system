module Authentication
  extend ActiveSupport::Concern

  class Unauthorized < StandardError; end

  included do
    rescue_from Unauthorized do |e|
      render json: { error: e.message }, status: :unauthorized
    end
  end

  def authenticate_user!
    token = bearer_token
    raise Unauthorized, "missing bearer token" if token.blank?

    payload = JwtToken.decode(token)
    user = User.find_by(id: payload["sub"])
    raise Unauthorized, "user not found" unless user

    Current.user = user
  rescue JwtToken::DecodeError => e
    raise Unauthorized, e.message
  end

  def current_user
    Current.user
  end

  private

  def bearer_token
    h = request.headers["Authorization"].to_s
    return nil unless h.start_with?("Bearer ")
    h.delete_prefix("Bearer ").strip
  end
end


