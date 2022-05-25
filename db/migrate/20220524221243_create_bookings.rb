class CreateBookings < ActiveRecord::Migration[6.1]
  def change
    create_table :bookings do |t|
      t.integer :property_id
      t.string :guest_name
      t.string :platform
      t.string :confirmation_code
      t.date :check_in
      t.date :check_out
      t.integer :nights
      t.decimal :payout
      t.string :notes

      t.timestamps
    end
  end
end
