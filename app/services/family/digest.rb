# The 7am "today" digest: today's events, tasks due today, anything overdue.
# Skipped on an empty day. Sent once per day per device (last_digest_on).
module Family::Digest
  module_function

  # Returns a short summary string for the log.
  def send_morning!(day, force: false)
    events  = Family::Event.overlapping(day..day).includes(:person).to_a
    due     = Family::Task.open.where(due_on: day).includes(:list).to_a
    overdue = Family::Task.open.where("due_on < ?", day).count
    return "nothing to say for #{day}" if events.empty? && due.empty? && overdue.zero?

    body  = body_for(events, due, overdue)
    url   = events.any? ? "/family/calendar" : "/family/tasks"
    subs  = Family::PushSubscription.includes(:user)
    subs  = subs.where("last_digest_on IS NULL OR last_digest_on < ?", day) unless force

    sent = 0
    subs.find_each do |sub|
      if Family::Notifier.deliver(sub, title: "Nash Family · Today", body: body, url: url, tag: "digest-#{day}")
        sub.update_column(:last_digest_on, day)
        sent += 1
      end
    end
    "sent to #{sent} device(s) — #{body.gsub("\n", ' / ')}"
  end

  # Two short lines at most; push bodies get cut off around 150-200 chars.
  def body_for(events, due, overdue)
    lines = []
    if events.any?
      lines << events.first(3).map { |e| e.all_day? ? e.title : "#{e.title} #{e.short_time}" }.join(" · ") +
               (events.size > 3 ? " · +#{events.size - 3} more" : "")
    end
    tasks = []
    tasks << "Due: " + due.first(2).map(&:title).join(", ") + (due.size > 2 ? " +#{due.size - 2}" : "") if due.any?
    tasks << "#{overdue} overdue" if overdue.positive?
    lines << tasks.join(" · ") if tasks.any?
    lines.join("\n")
  end
end
