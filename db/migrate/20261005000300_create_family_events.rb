# Calendar events for the Family App. Deliberately plain: a title, the day (or
# span of days) it falls on, and optional times. A blank start_time means an
# all-day event, which is how most family entries actually work.
class CreateFamilyEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :family_events do |t|
      t.string  :title,     null: false
      t.date    :starts_on, null: false
      t.date    :ends_on                  # blank = same day; set for multi-day
      t.time    :start_time               # blank = all day
      t.time    :end_time
      t.string  :location
      t.text    :notes
      t.bigint  :person_id                # who it's for, optional
      t.bigint  :created_by_id
      t.timestamps
    end
    add_index :family_events, :starts_on
    add_index :family_events, :person_id
    add_foreign_key :family_events, :users, column: :person_id,     on_delete: :nullify
    add_foreign_key :family_events, :users, column: :created_by_id, on_delete: :nullify
  end
end
