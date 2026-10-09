# Sends Web Push notifications to family members' devices.
#
# Best-effort by design: a dead subscription is removed, any other failure is
# logged and skipped, and nothing here ever raises into a request. With push
# not configured (no VAPID keys) every call is a quiet no-op.
#
#   Family::Notifier.notify(users, title: "...", body: "...", url: "/family/...")
#   Family::Notifier.notify_others(current_user, ...)   # everyone but the actor
module Family::Notifier
  GONE = [404, 410].freeze

  module_function

  # Everyone except `actor` — the "Notify Christina" checkbox.
  def notify_others(actor, **message)
    notify(User.where.not(id: actor&.id), **message)
  end

  def notify(users, title:, body:, url: "/family", tag: nil)
    return 0 unless FamilyPush.enabled?
    subs = Family::PushSubscription.for_users(users).includes(:user)
    subs.sum { |sub| deliver(sub, title: title, body: body, url: url, tag: tag) ? 1 : 0 }
  end

  # One device. Returns true on success. Removes the subscription when the
  # push service says it no longer exists.
  def deliver(sub, title:, body:, url:, tag: nil)
    payload = { title: title, body: body, url: url, tag: tag }.compact.to_json
    WebPush.payload_send(
      message: payload,
      endpoint: sub.endpoint, p256dh: sub.p256dh, auth: sub.auth,
      vapid: { subject: FamilyPush::SUBJECT, public_key: FamilyPush.keys[:public], private_key: FamilyPush.keys[:private] },
      ttl: 12.hours.to_i, urgency: "normal",
      open_timeout: 5, read_timeout: 10
    )
    true
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription => e
    Rails.logger.info "[family push] subscription gone for user #{sub.user_id} (#{e.class}); removing"
    sub.destroy
    false
  rescue WebPush::ResponseError => e
    if GONE.include?(e.response&.code.to_i)
      Rails.logger.info "[family push] #{e.response.code} for user #{sub.user_id}; removing subscription"
      sub.destroy
    else
      Rails.logger.warn "[family push] send failed for user #{sub.user_id}: #{e.message}"
    end
    false
  rescue StandardError => e
    Rails.logger.warn "[family push] send failed for user #{sub.user_id}: #{e.class}: #{e.message}"
    false
  end
end
