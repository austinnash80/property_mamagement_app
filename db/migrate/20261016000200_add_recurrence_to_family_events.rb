class AddRecurrenceToFamilyEvents < ActiveRecord::Migration[6.1]
  def change
    add_column :family_events, :repeat_frequency, :string, null: false, default: "none"
    add_column :family_events, :repeat_until, :date
    add_reference :family_events, :recurrence_parent, foreign_key: { to_table: :family_events }, index: false
    add_column :family_events, :original_on, :date
    add_column :family_events, :cancelled, :boolean, null: false, default: false
    add_index :family_events, [:recurrence_parent_id, :original_on], unique: true,
              name: "index_family_events_on_series_and_original_date"
  end
end
