# Scheduled push for the Family App. Heroku Scheduler runs `family:push:tick`
# every hour; the task decides what (if anything) is due at this Pacific hour.
# Safe to run more often than hourly: each digest is sent once per day per
# device, tracked on the subscription.
namespace :family do
  namespace :push do
    DIGEST_HOUR = 7   # Pacific, see Family::ZONE

    desc "Hourly tick: send the morning digest when it's #{DIGEST_HOUR}am Pacific"
    task tick: :environment do
      now = Time.now.in_time_zone(Family::ZONE)
      if now.hour == DIGEST_HOUR
        sent = Family::Digest.send_morning!(now.to_date)
        puts "[family push] #{now.strftime('%F %H:%M %Z')} morning digest: #{sent}"
      else
        puts "[family push] #{now.strftime('%F %H:%M %Z')} nothing due this hour"
      end
    end

    desc "Send the morning digest right now, regardless of the hour (for testing)"
    task digest_now: :environment do
      puts "[family push] forced digest: #{Family::Digest.send_morning!(Family.today, force: true)}"
    end
  end
end
