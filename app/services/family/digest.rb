# The 7am "today" digest. Each person gets their own events plus Everyone
# events, and a count of the open to-dos assigned to them. A ping goes out
# every morning, even on a free day. Sent once per day per device
# (last_digest_on).
module Family::Digest
  module_function

  FREE_DAY = "Nothing on the calendar today".freeze

  # Returns a short summary string for the log.
  def send_morning!(day, force: false)
    events = Family::Event.overlapping(day..day).to_a
    todos  = Family::Task.active.unfinished.where.not(assignee_id: nil).group(:assignee_id).count
    subs = Family::PushSubscription.all
    subs = subs.where("last_digest_on IS NULL OR last_digest_on < ?", day) unless force

    sent = 0
    subs.find_each do |sub|
      body = body_for(events_for(events, sub.user_id), day, todos: todos.fetch(sub.user_id, 0))
      if Family::Notifier.deliver(sub, title: "Nash Family · Today", body: body, url: "/family/calendar", tag: "digest-#{day}")
        sub.update_column(:last_digest_on, day)
        sent += 1
      end
    end
    "sent to #{sent} device(s) for #{day}"
  end

  # One person's share of the day: theirs, plus anything for everyone.
  def events_for(events, user_id)
    events.select { |e| e.person_id.nil? || e.person_id == user_id }
  end

  # One short line; push bodies get cut off around 150-200 chars.
  # "Dentist 3:30p · 2 to-dos for you". To-dos go last; they're just a count.
  def body_for(events, day, todos: 0)
    parts = events.first(3).map { |e| line_for(e, day) }
    parts = [FREE_DAY] if parts.empty?
    parts << "+#{events.size - 3} more" if events.size > 3
    parts << "#{todos} #{'to-do'.pluralize(todos)} for you" if todos.positive?
    parts.join(" · ")
  end

  # "Dentist 3:30p", "Dinner at Mom's 6p (both)", "Tahoe (both, day 2 of 3)".
  # A multi-day event only shows its time on the first day.
  def line_for(event, day)
    first_day = day == event.starts_on
    text = [event.title, (event.short_time if first_day)].compact.join(" ")
    notes = []
    notes << "both" if event.person_id.nil?
    notes << "day #{(day - event.starts_on).to_i + 1} of #{event.days.count}" if event.multi_day?
    notes.any? ? "#{text} (#{notes.join(', ')})" : text
  end
end
