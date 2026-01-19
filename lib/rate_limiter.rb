class RateLimiter
  DEFAULTS = {
    "POST /login" => { limit: 20, period: 60 }, # 20/min per IP
    "POST /signup" => { limit: 10, period: 60 }, # 10/min per IP
    "POST /api/payments/create_order" => { limit: 30, period: 60 },
    "POST /api/payments/verify" => { limit: 30, period: 60 }
  }.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) if Rails.env.test?
    return @app.call(env) unless ENV.fetch("RATE_LIMITING_ENABLED", "1") == "1"

    req = Rack::Request.new(env)
    rule = rule_for(req)
    return @app.call(env) unless rule

    limit = rule.fetch(:limit).to_i
    period = rule.fetch(:period).to_i
    key = cache_key(req, rule_key(req))

    count = Rails.cache.increment(key, 1, expires_in: period)
    if count.to_i > limit
      body = { error: "rate_limited", limit: limit, period_seconds: period }.to_json
      return [429, { "Content-Type" => "application/json" }, [body]]
    end

    @app.call(env)
  end

  private

  def rule_for(req)
    DEFAULTS[rule_key(req)]
  end

  def rule_key(req)
    "#{req.request_method.upcase} #{req.path}"
  end

  def cache_key(req, rule_key)
    ip = req.ip.to_s
    "rl:v1:#{rule_key}:ip:#{ip}"
  end
end


