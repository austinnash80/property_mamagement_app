# A browser/device that has opted in to push. See Family::Notifier for sending.
class Family::PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, :p256dh, :auth, presence: true
  validates :endpoint, uniqueness: true

  scope :for_users, ->(users) { where(user_id: users) }

  # A rough device label for the settings line: "iPhone", "Mac", "Android".
  def device_label
    ua = user_agent.to_s
    return "iPhone"  if ua.include?("iPhone")
    return "iPad"    if ua.include?("iPad")
    return "Android" if ua.include?("Android")
    return "Mac"     if ua.include?("Macintosh")
    return "Windows" if ua.include?("Windows")
    "Device"
  end
end
