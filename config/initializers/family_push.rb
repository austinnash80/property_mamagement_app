# VAPID keys for Family App push notifications (see Family::Notifier).
#
# Production: ENV VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY (heroku config:set).
# Development: config/vapid.yml, git-ignored, written once by the setup step.
# Neither present: push is simply off — the opt-in control hides itself and
# sends are no-ops — so the rest of the app is unaffected.
module FamilyPush
  FILE = Rails.root.join("config/vapid.yml")

  def self.keys
    @keys ||= begin
      if ENV["VAPID_PUBLIC_KEY"].present? && ENV["VAPID_PRIVATE_KEY"].present?
        { public: ENV["VAPID_PUBLIC_KEY"], private: ENV["VAPID_PRIVATE_KEY"] }
      elsif FILE.exist?
        y = YAML.safe_load(FILE.read) || {}
        { public: y["public_key"], private: y["private_key"] }
      else
        {}
      end
    end
  end

  def self.enabled?
    keys[:public].present? && keys[:private].present?
  end

  # Shown in notifications and used as the VAPID contact.
  SUBJECT = "mailto:austin@sequoiacpe.com".freeze
end
