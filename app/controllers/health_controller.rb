class HealthController < ActionController::API
  def live
    render json: { status: "ok" }
  end

  # Ready means: app can serve traffic AND its dependencies are reachable.
  def ready
    checks = {}

    begin
      ActiveRecord::Base.connection.select_value("SELECT 1")
      checks[:db] = "ok"
    rescue StandardError => e
      checks[:db] = "error"
      checks[:db_error] = e.class.name
    end

    if ENV["REDIS_URL"].present?
      begin
        redis = Redis.new(url: ENV["REDIS_URL"])
        redis.ping
        checks[:redis] = "ok"
      rescue StandardError => e
        checks[:redis] = "error"
        checks[:redis_error] = e.class.name
      end
    end

    ok = checks.values.none? { |v| v == "error" }
    status = ok ? :ok : :service_unavailable
    render json: { status: ok ? "ok" : "degraded", checks: checks }, status: status
  end
end
