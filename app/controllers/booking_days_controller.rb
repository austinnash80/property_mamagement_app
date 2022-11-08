class BookingDaysController < ApplicationController
  before_action :set_booking_day, only: %i[ show edit update destroy ]

  # GET /booking_days or /booking_days.json
  def index
    @booking_days = BookingDay.all
  end

  # GET /booking_days/1 or /booking_days/1.json
  def show
  end

  # GET /booking_days/new
  def new
    @booking_day = BookingDay.new
  end

  # GET /booking_days/1/edit
  def edit
  end

  # POST /booking_days or /booking_days.json
  def create
    @booking_day = BookingDay.new(booking_day_params)

    respond_to do |format|
      if @booking_day.save
        format.html { redirect_to booking_day_url(@booking_day), notice: "Booking day was successfully created." }
        format.json { render :show, status: :created, location: @booking_day }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @booking_day.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /booking_days/1 or /booking_days/1.json
  def update
    respond_to do |format|
      if @booking_day.update(booking_day_params)
        format.html { redirect_to booking_day_url(@booking_day), notice: "Booking day was successfully updated." }
        format.json { render :show, status: :ok, location: @booking_day }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @booking_day.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /booking_days/1 or /booking_days/1.json
  def destroy
    @booking_day.destroy

    respond_to do |format|
      format.html { redirect_to booking_days_url, notice: "Booking day was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_booking_day
      @booking_day = BookingDay.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def booking_day_params
      params.require(:booking_day).permit(:day, :property_id, :day_rate, :extra_s, :extra_i, :extra_b)
    end
end
