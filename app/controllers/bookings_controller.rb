class BookingsController < ApplicationController
  before_action :set_booking, only: %i[ show edit update destroy ]

require "csv"
  # =========================
  # EXPORT FULL TABLE
  # =========================
  def export_csv
    csv = CSV.generate(headers: true) do |out|
      out << csv_headers

      Booking.find_each do |b|
        out << [
          b.id,
          b.property_id,
          b.guest_name,
          b.platform,
          b.confirmation_code,
          b.check_in,
          b.check_out,
          b.nights,
          b.payout,
          b.notes,
          b.created_at,
          b.updated_at
        ]
      end
    end

    send_data csv,
      filename: "bookings-#{Time.zone.now.strftime('%Y-%m-%d_%H%M')}.csv",
      type: "text/csv"
  end

  # =========================
  # IMPORT CSV (UPSERT)
  # =========================
  def import_csv
    file = params[:file]
    unless file&.respond_to?(:read)
      redirect_to bookings_path, alert: "Please choose a CSV file."
      return
    end

    rows = []
    CSV.foreach(file.path, headers: true) { |row| rows << row.to_h }

    Booking.transaction do
      rows.each_with_index do |h, idx|
        attrs = sanitize_csv_row(h)

        if attrs[:id].present?
          rec = Booking.find_by(id: attrs[:id])

          if rec
            rec.update!(attrs.except(:id, :created_at, :updated_at))
          else
            Booking.create!(attrs.except(:created_at, :updated_at))
          end
        else
          Booking.create!(attrs.except(:id, :created_at, :updated_at))
        end

      rescue ActiveRecord::RecordInvalid => e
        raise ActiveRecord::Rollback,
          "Row #{idx + 1}: #{e.record.errors.full_messages.join(', ')}"
      end
    end

    redirect_to bookings_path, notice: "Import complete (#{rows.size} rows processed)."

  rescue => e
    redirect_to bookings_path, alert: "Import failed: #{e.message}"
  end

  # GET /bookings or /bookings.json
  def index
    if params['property'].present?
      @bookings = Booking.where(property_id: params['property']).all
    else
      @bookings = Booking.all
    end
  end

  # GET /bookings/1 or /bookings/1.json
  def show
  end

  # GET /bookings/new
  def new
    @booking = Booking.new
  end

  # GET /bookings/1/edit
  def edit
  end

  # POST /bookings or /bookings.json
  def create
    @booking = Booking.new(booking_params)

    respond_to do |format|
      if @booking.save
        format.html { redirect_to pages_manage_property_path(property: @booking.property_id), notice: "Booking was successfully created." }
        format.json { render :show, status: :created, location: @booking }
        #add the nights and enter into the field
        Booking.where(id: @booking.id).update_all nights: (@booking.check_out - @booking.check_in).to_i
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @booking.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /bookings/1 or /bookings/1.json
  def update
    respond_to do |format|
      if @booking.update(booking_params)
        format.html { redirect_to booking_url(@booking), notice: "Booking was successfully updated." }
        format.json { render :show, status: :ok, location: @booking }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @booking.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /bookings/1 or /bookings/1.json
  def destroy
    @booking.destroy

    respond_to do |format|
      format.html { redirect_to bookings_url, notice: "Booking was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_booking
      @booking = Booking.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def booking_params
      params.require(:booking).permit(:property_id, :guest_name, :platform, :confirmation_code, :check_in, :check_out, :nights, :payout, :notes)
    end

  def csv_headers
    %w[
      id
      property_id
      guest_name
      platform
      confirmation_code
      check_in
      check_out
      nights
      payout
      notes
      created_at
      updated_at
    ]
  end


  # Cast string CSV values to correct Ruby types
  def sanitize_csv_row(h)
    {
      id:                h["id"].presence,
      property_id:       h["property_id"].presence&.to_i,
      guest_name:        h["guest_name"].to_s.presence,
      platform:          h["platform"].to_s.presence,
      confirmation_code: h["confirmation_code"].to_s.presence,
      check_in:          h["check_in"].presence && Date.parse(h["check_in"]),
      check_out:         h["check_out"].presence && Date.parse(h["check_out"]),
      nights:            h["nights"].presence&.to_i,
      payout:            h["payout"].presence && BigDecimal(h["payout"].to_s),
      notes:             h["notes"].to_s,
      created_at:        h["created_at"].presence && Time.zone.parse(h["created_at"]),
      updated_at:        h["updated_at"].presence && Time.zone.parse(h["updated_at"])
    }
  end
end
