class AddRepeatDaysToFamilyEvents < ActiveRecord::Migration[6.1]
  def change
    add_column :family_events, :repeat_weekday, :integer
    add_column :family_events, :repeat_day_of_month, :integer
  end
end
