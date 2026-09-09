class ApplicationController < ActionController::Base
  # One shared password for the whole app (HTTP Basic). Set APP_PASSWORD (and
  # optionally APP_USER) in the environment / Heroku config vars. When
  # APP_PASSWORD is blank (local development) the app is open.
  # Controllers can override public_request? to allow anonymous reads
  # (the portfolio does this for license reviewers).
  before_action :require_password
  helper_method :signed_in?

  private

  def require_password
    return if ENV["APP_PASSWORD"].blank? || public_request?
    authenticate_or_request_with_http_basic("Nash Properties") { |user, pass| valid_credentials?(user, pass) }
  end

  def valid_credentials?(user, pass)
    ActiveSupport::SecurityUtils.secure_compare(pass.to_s, ENV["APP_PASSWORD"].to_s) &&
      (ENV["APP_USER"].blank? || ActiveSupport::SecurityUtils.secure_compare(user.to_s, ENV["APP_USER"].to_s))
  end

  def public_request?
    false
  end

  # True when no password is configured or the browser sent valid credentials.
  def signed_in?
    return true if ENV["APP_PASSWORD"].blank?
    authenticate_with_http_basic { |user, pass| valid_credentials?(user, pass) } || false
  end
end
