class CreateBookingDays < ActiveRecord::Migration[6.1]
  def change
    create_table :booking_days do |t|
      t.date :day
      t.integer :property_id
      t.decimal :day_rate
      t.string :extra_s
      t.integer :extra_i
      t.boolean :extra_b

      t.timestamps
    end
  end
end
