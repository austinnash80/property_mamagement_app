class User < ApplicationRecord
  has_secure_password

  before_validation { self.email = email.to_s.strip.downcase }
  before_validation { self.remember_token ||= self.class.new_token }

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def self.new_token
    SecureRandom.urlsafe_base64(32)
  end

  # Invalidates every browser's persistent cookie (used after a password change).
  def rotate_remember_token!
    update!(remember_token: self.class.new_token)
  end
end
