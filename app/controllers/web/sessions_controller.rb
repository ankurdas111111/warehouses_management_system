module Web
  class SessionsController < BaseController
    def new; end

    def create
      email = params[:email].to_s.strip.downcase
      password = params[:password].to_s

      user = User.find_by(email: email)
      if user&.authenticate(password)
        token = JwtToken.encode({ "sub" => user.id })
        cookies.encrypted[:jwt] = {
          value: token,
          httponly: true,
          same_site: :lax,
          secure: Rails.env.production?
        }
        redirect_to root_path, notice: "Logged in."
      else
        @error = "Invalid email or password"
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      cookies.delete(:jwt)
      redirect_to login_path, notice: "Logged out."
    end
  end
end
