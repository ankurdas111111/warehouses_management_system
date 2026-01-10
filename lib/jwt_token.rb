class JwtToken
  class DecodeError < StandardError; end

  ALGORITHM = "HS256"

  def self.encode(payload, expires_in: 7.days)
    payload = payload.dup
    payload["exp"] ||= expires_in.from_now.to_i
    JWT.encode(payload, secret, ALGORITHM)
  end

  def self.decode(token)
    raise DecodeError, "missing token" if token.blank?

    decoded, = JWT.decode(token, secret, true, { algorithm: ALGORITHM })
    decoded
  rescue JWT::DecodeError, JWT::ExpiredSignature => e
    raise DecodeError, e.message
  end

  def self.secret
    ENV["JWT_SECRET"].presence || Rails.application.secret_key_base
  end
end


