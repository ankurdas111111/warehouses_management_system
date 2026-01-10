module Ui
  class RegistrationsController < BaseController
    def new; end

    def create
      email = params[:email].to_s.strip.downcase
      password = params[:password].to_s

      user = User.new(email: email, password: password, password_confirmation: password)
      user.save!

      token = JwtToken.encode({ "sub" => user.id })
      cookies.encrypted[:jwt] = {
        value: token,
        httponly: true,
        same_site: :lax,
        secure: Rails.env.production?
      }

      redirect_to root_path, notice: "Account created."
    rescue ActiveRecord::RecordInvalid => e
      @error = e.record.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end
end


