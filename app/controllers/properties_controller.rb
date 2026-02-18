class PropertiesController < ApplicationController
  before_action :set_property, only: %i[ show edit update destroy ]

  # GET /properties or /properties.json

  require "csv"

  # GET /properties/export_csv
  def export_csv
    csv = CSV.generate(headers: true) do |out|
      out << csv_headers

      Property.find_each do |p|
        out << [
          p.id,
          p.nickname,
          p.address,
          p.picture,
          p.bed,
          p.bath,
          p.sq_ft,
          p.notes,
          p.created_at,
          p.updated_at
        ]
      end
    end

    send_data csv,
      filename: "properties-#{Time.zone.now.strftime('%Y-%m-%d_%H%M')}.csv",
      type: "text/csv"
  end

  # POST /properties/import_csv
  def import_csv
    file = params[:file]
    unless file&.respond_to?(:read)
      redirect_to properties_path, alert: "Please choose a CSV file."
      return
    end

    rows = []
    CSV.foreach(file.path, headers: true) { |row| rows << row.to_h }

    Property.transaction do
      rows.each_with_index do |h, idx|
        attrs = sanitize_csv_row(h)

        if attrs[:id].present?
          rec = Property.find_by(id: attrs[:id])

          if rec
            rec.update!(attrs.except(:id, :created_at, :updated_at))
          else
            Property.create!(attrs.except(:created_at, :updated_at))
          end
        else
          Property.create!(attrs.except(:id, :created_at, :updated_at))
        end

      rescue ActiveRecord::RecordInvalid => e
        raise ActiveRecord::Rollback,
          "Row #{idx + 1}: #{e.record.errors.full_messages.join(', ')}"
      end
    end

    redirect_to properties_path, notice: "Import complete (#{rows.size} rows processed)."
  rescue => e
    redirect_to properties_path, alert: "Import failed: #{e.message}"
  end

  def index
    @properties = Property.all
  end

  # GET /properties/1 or /properties/1.json
  def show
  end

  # GET /properties/new
  def new
    @property = Property.new
  end

  # GET /properties/1/edit
  def edit
  end

  # POST /properties or /properties.json
  def create
    @property = Property.new(property_params)

    respond_to do |format|
      if @property.save
        format.html { redirect_to property_url(@property), notice: "Property was successfully created." }
        format.json { render :show, status: :created, location: @property }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @property.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /properties/1 or /properties/1.json
  def update
    respond_to do |format|
      if @property.update(property_params)
        format.html { redirect_to property_url(@property), notice: "Property was successfully updated." }
        format.json { render :show, status: :ok, location: @property }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @property.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /properties/1 or /properties/1.json
  def destroy
    @property.destroy

    respond_to do |format|
      format.html { redirect_to properties_url, notice: "Property was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_property
      @property = Property.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def property_params
      params.require(:property).permit(:nickname, :address, :picture, :bed, :bath, :sq_ft, :notes)
    end

      def csv_headers
    %w[
      id
      nickname
      address
      picture
      bed
      bath
      sq_ft
      notes
      created_at
      updated_at
    ]
  end

  def sanitize_csv_row(h)
    {
      id:         h["id"].presence,
      nickname:   h["nickname"].to_s.presence,
      address:    h["address"].to_s.presence,
      picture:    h["picture"].to_s.presence,
      bed:        h["bed"].presence && BigDecimal(h["bed"].to_s),
      bath:       h["bath"].presence && BigDecimal(h["bath"].to_s),
      sq_ft:      h["sq_ft"].presence&.to_i,
      notes:      h["notes"].to_s,
      created_at: h["created_at"].presence && Time.zone.parse(h["created_at"].to_s),
      updated_at: h["updated_at"].presence && Time.zone.parse(h["updated_at"].to_s)
    }
  end
end
