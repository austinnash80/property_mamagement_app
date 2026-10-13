# Login throttling. The site is on the open internet, passwords can be as short
# as 4 characters, and the Family section holds door codes and health details,
# so cap how fast anyone can guess at /login. Everyone stays signed in on their
# own devices, so the limits only matter to someone actually typing a password.
#
# Counts live in this process's memory (one Eco dyno, no Redis), so they reset
# when the dyno restarts or sleeps. That's still enough to make guessing slow.
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

# The test suite signs in from one address over and over; the throttle test
# turns this back on for itself.
Rack::Attack.enabled = !Rails.env.test?

# Per address: room for a few typos, not for a script.
Rack::Attack.throttle("logins/ip", limit: 10, period: 15.minutes) do |req|
  req.ip if req.post? && req.path == "/login"
end

# Per account, from anywhere: stops guesses spread across many addresses.
Rack::Attack.throttle("logins/email", limit: 20, period: 1.day) do |req|
  req.params["email"].to_s.strip.downcase.presence if req.post? && req.path == "/login"
end

Rack::Attack.throttled_responder = lambda do |_request|
  [429, { "Content-Type" => "text/plain" }, ["Too many sign-in attempts. Please wait a while and try again.\n"]]
end
