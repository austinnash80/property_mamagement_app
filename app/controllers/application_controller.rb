class ApplicationController < ActionController::Base
  # Single-account sign-in with a persistent cookie: the browser stays signed in
  # until the user signs out or changes their password. Controllers can override
  # public_request? to allow anonymous reads (the portfolio does, for reviewers).
  before_action :require_login
  helper_method :signed_in?, :current_user

  private

  def current_user
    return @current_user if defined?(@current_user)
    token = cookies.signed[:remember_token]
    @current_user = token.present? ? User.find_by(remember_token: token) : nil
  end

  def signed_in?
    current_user.present?
  end

  def require_login
    return if signed_in? || public_request?
    return if Rails.env.development? && User.none?   # fresh dev database: nothing to sign in with yet
    session[:return_to] = request.fullpath if request.get?
    redirect_to login_path, alert: "Please sign in."
  end

  def public_request?
    false
  end

  def sign_in(user)
    cookies.permanent.signed[:remember_token] = { value: user.remember_token, httponly: true, secure: Rails.env.production?, same_site: :lax }
    @current_user = user
  end

  def sign_out
    cookies.delete(:remember_token)
    @current_user = nil
  end
end
