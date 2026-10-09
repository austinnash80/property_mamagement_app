# Shared by the Family controllers: when the "Notify Christina" box was ticked
# on a create form, push a one-line message to everyone except the person who
# added the entry. Never raises; a failed send is logged by the notifier.
module FamilyNotifies
  extend ActiveSupport::Concern

  private

  def notify_requested?
    params[:notify].present?
  end

  # body: "Austin added a task: Replace the faucet (Home improvement, for Christina)"
  def notify_others_about(kind, title, detail: nil, url:)
    return unless notify_requested?
    who  = current_user&.display_name || "Someone"
    body = "#{who} added #{kind.start_with?(*%w[a e i o u]) ? 'an' : 'a'} #{kind}: #{title}"
    body += " (#{detail})" if detail.present?
    Family::Notifier.notify_others(current_user, title: "Nash Family", body: body, url: url)
  end
end
