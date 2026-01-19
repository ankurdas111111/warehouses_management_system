module Admin
  class BaseController < ActionController::Base
    protect_from_forgery with: :exception
    layout "application"

    before_action :require_admin_basic_auth
    before_action :set_current_request_context
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

    def set_current_request_context
      Current.request_id = request.request_id
      Current.request_path = request.fullpath
      Current.request_method = request.request_method
      Current.ip = request.remote_ip
      Current.user = nil

      u, = ActionController::HttpAuthentication::Basic.user_name_and_password(request)
      Current.admin_user = u.to_s.presence
    end
  end
end


