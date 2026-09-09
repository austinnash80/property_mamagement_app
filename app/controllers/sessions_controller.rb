class SessionsController < ApplicationController
  skip_before_action :require_login
  layout "auth"

  def new
    redirect_to root_path if signed_in?
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    if user&.authenticate(params[:password])
      sign_in(user)
      redirect_to session.delete(:return_to) || root_path, notice: "Signed in."
    else
      flash.now[:alert] = "That email and password didn't match."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out
    redirect_to login_path, notice: "Signed out."
  end
end
