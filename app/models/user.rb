class User < ApplicationRecord
  has_secure_password

  # See AddRolesToUsers. "owner" runs the app, "full" can use every section but
  # not manage accounts, "family" is limited to the Family App.
  ROLES = %w[owner full family].freeze

  before_validation { self.email = email.to_s.strip.downcase }
  before_validation { self.remember_token ||= self.class.new_token }

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 4 }, allow_nil: true
  validates :role, inclusion: { in: ROLES }

  scope :by_name, -> { order(Arel.sql("COALESCE(NULLIF(name, ''), email)")) }

  def owner?        = role == "owner"
  def full_access?  = %w[owner full].include?(role)
  def family_only?  = role == "family"

  # Falls back to the part of the email before the @ so there is always
  # something to show next to a task.
  def display_name
    name.presence || email.to_s.split("@").first
  end

  def self.new_token
    SecureRandom.urlsafe_base64(32)
  end

  # Invalidates every browser's persistent cookie (used after a password change).
  def rotate_remember_token!
    update!(remember_token: self.class.new_token)
  end
end
