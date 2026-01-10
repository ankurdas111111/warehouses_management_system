module Admin
  class SessionsController < BaseController
    def destroy
      request_http_basic_authentication("Admin")
    end
  end
end


