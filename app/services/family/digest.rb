# The 7am "today" digest: the day's events. Skipped on an empty day. Sent once
# per day per device (last_digest_on).
module Family::Digest
  module_function

  # Returns a short summary string for the log.
  def send_morning!(day, force: false)
    events = Family::Event.overlapping(day..day).includes(:person).to_a
    return "nothing to say for #{day}" if events.empty?

    body = body_for(events)
    subs = Family::PushSubscription.includes(:user)
    subs = subs.where("last_digest_on IS NULL OR last_digest_on < ?", day) unless force

    sent = 0
    subs.find_each do |sub|
      if Family::Notifier.deliver(sub, title: "Nash Family · Today", body: body, url: "/family/calendar", tag: "digest-#{day}")
        sub.update_column(:last_digest_on, day)
        sent += 1
      end
    end
    "sent to #{sent} device(s) — #{body}"
  end

  # One short line; push bodies get cut off around 150-200 chars.
  def body_for(events)
    events.first(3).map { |e| e.all_day? ? e.title : "#{e.title} #{e.short_time}" }.join(" · ") +
      (events.size > 3 ? " · +#{events.size - 3} more" : "")
  end
end
