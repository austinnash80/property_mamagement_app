# One row per person per device that has tapped "Turn on notifications".
# endpoint/p256dh/auth are what the browser hands back from PushManager and
# what the push service needs to deliver. A subscription the push service
# reports gone (404/410) is deleted on the next send.
class CreateFamilyPushSubscriptions < ActiveRecord::Migration[6.1]
  def change
    create_table :family_push_subscriptions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.text    :endpoint, null: false
      t.string  :p256dh,   null: false
      t.string  :auth,     null: false
      t.string  :user_agent
      t.date    :last_digest_on          # so the 7am digest goes once per day per device
      t.timestamps
    end
    add_index :family_push_subscriptions, :endpoint, unique: true
  end
end
