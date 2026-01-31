require "securerandom"
require "openssl"

module DummyGateway
  class Error < StandardError; end

  # Backward-compatible env keys:
  # - Prefer DUMMY_GATEWAY_KEY_ID / DUMMY_GATEWAY_KEY_SECRET
  # - Fall back to legacy env keys if present
  def self.key_id
    ENV["DUMMY_GATEWAY_KEY_ID"].presence || ENV.fetch("DUMMY_GATEWAY_KEY_ID_LEGACY", "dummy_test_key")
  end

  def self.key_secret
    ENV["DUMMY_GATEWAY_KEY_SECRET"].presence || ENV.fetch("DUMMY_GATEWAY_KEY_SECRET_LEGACY", "dummy_secret_change_me")
  end

  # Amount is in INR minor unit (paise) to mirror typical gateway APIs.
  def self.create_order(amount_paise:, receipt:)
    raise Error, "amount must be > 0" unless amount_paise.to_i.positive?

    {
      id: "order_#{SecureRandom.hex(10)}",
      amount: amount_paise.to_i,
      currency: "INR",
      receipt: receipt.to_s,
      status: "created"
    }
  end

  # Signature: HMAC_SHA256("#{order_id}|#{payment_id}", secret)
  def self.signature_for(order_id:, payment_id:)
    payload = "#{order_id}|#{payment_id}"
    OpenSSL::HMAC.hexdigest("SHA256", key_secret, payload)
  end

  def self.verify!(order_id:, payment_id:, signature:)
    expected = signature_for(order_id: order_id, payment_id: payment_id)
    ok = ActiveSupport::SecurityUtils.secure_compare(signature.to_s, expected.to_s)
    raise Error, "invalid signature" unless ok
    true
  end
end
