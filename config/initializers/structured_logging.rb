require "json"

# Minimal structured logging via ActiveSupport::Notifications.
# We emit JSON log lines for key domain events (especially reservations).
module StructuredLogging
  def self.log(event_name:, payload:, duration_ms: nil)
    data = payload.dup
    data[:event] = event_name
    data[:duration_ms] = duration_ms if duration_ms
    data[:timestamp] = Time.current.iso8601
    data[:env] = Rails.env
    data[:request_id] ||= Current.request_id if defined?(Current)
    data[:user_id] ||= Current.user&.id if defined?(Current)
    data[:admin_user] ||= Current.admin_user if defined?(Current)
    data[:path] ||= Current.request_path if defined?(Current)
    data[:method] ||= Current.request_method if defined?(Current)

    Rails.logger.info(data.to_json)
  end
end

# Subscribe to domain-level events so they show up cleanly in Render logs and are easy to forward later.
ActiveSupport::Notifications.subscribe(/^(orders|inventory|reservation|wallet|payments|gateway|reports)\./) do |name, start, finish, _id, payload|
  duration_ms = ((finish - start) * 1000.0).round(1)
  StructuredLogging.log(event_name: name, payload: payload || {}, duration_ms: duration_ms)
end
