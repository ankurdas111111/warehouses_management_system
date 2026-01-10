module Admin
  class BaseController < ActionController::Base
    protect_from_forgery with: :exception
    layout "application"

    before_action :require_admin_basic_auth
    helper_method :warehouse_locations

    private

    def warehouse_locations
      env = ENV["WAREHOUSE_LOCATIONS"].to_s.split(",").map(&:strip).reject(&:blank?)
      return env if env.any?

      db = Warehouse.distinct.order(:location).pluck(:location).compact
      (IndianCities::CITIES + db).map(&:to_s).map(&:strip).reject(&:blank?).uniq.sort
    end

    def require_admin_basic_auth
      expected_user = ENV.fetch("ADMIN_USER", "admin")
      expected_pass = ENV.fetch("ADMIN_PASSWORD", "admin")

      authenticate_or_request_with_http_basic("Admin") do |user, pass|
        ActiveSupport::SecurityUtils.secure_compare(user.to_s, expected_user) &
          ActiveSupport::SecurityUtils.secure_compare(pass.to_s, expected_pass)
      end
    end
  end
end


