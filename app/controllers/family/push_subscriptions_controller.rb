# Where the browser sends its push subscription after "Turn on notifications",
# and where it removes it on "Turn off". Also a one-tap test send so you can
# confirm delivery on a real phone.
class Family::PushSubscriptionsController < Family::BaseController
  # Only JSON from our own page; the CSRF token is sent as a header.
  def create
    sub = Family::PushSubscription.find_or_initialize_by(endpoint: params.require(:endpoint))
    sub.assign_attributes(user: current_user, p256dh: params.require(:p256dh), auth: params.require(:auth),
                          user_agent: request.user_agent.to_s.first(255))
    if sub.save
      render json: { ok: true, id: sub.id }
    else
      render json: { ok: false, errors: sub.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    Family::PushSubscription.where(user: current_user, endpoint: params.require(:endpoint)).destroy_all
    head :no_content
  end

  # Sends a test notification to the signed-in person's own devices.
  def test
    sent = Family::Notifier.notify([current_user], title: "Nash Family",
                                   body: "Notifications are on for this device. 🎉", url: "/family", tag: "test")
    redirect_back fallback_location: family_root_path,
                  notice: (sent.positive? ? "Test notification sent to #{sent} #{'device'.pluralize(sent)}." : "No devices are turned on for you yet.")
  end
end
