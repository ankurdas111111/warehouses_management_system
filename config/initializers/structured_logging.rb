require "json"

# Minimal structured logging via ActiveSupport::Notifications.
# We emit JSON log lines for key domain events (especially reservations).
module StructuredLogging
  def self.log(event_name:, payload:, duration_ms: nil)
    data = payload.dup
    data[:event] = event_name
    data[:duration_ms] = duration_ms if duration_ms
    data[:timestamp] = Time.current.iso8601

    Rails.logger.info(data.to_json)
  end
end

ActiveSupport::Notifications.subscribe(/^(orders|inventory|reservation)\./) do |name, start, finish, _id, payload|
  duration_ms = ((finish - start) * 1000.0).round(1)
  StructuredLogging.log(event_name: name, payload: payload || {}, duration_ms: duration_ms)
end


