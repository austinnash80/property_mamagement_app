json.extract! booking, :id, :property_id, :guest_name, :platform, :confirmation_code, :check_in, :check_out, :nights, :payout, :notes, :created_at, :updated_at
json.url booking_url(booking, format: :json)
