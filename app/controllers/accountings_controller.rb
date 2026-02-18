class AccountingsController < ApplicationController
  before_action :set_accounting, only: %i[ show edit update destroy ]
  # GET /accountings or /accountings.json

  # Upload/Download
  require "csv"

# GET /accountings/export_csv
  def export_csv
    csv = CSV.generate(headers: true) do |out|
      out << csv_headers

      Accounting.find_each do |a|
        out << [
          a.id,
          a.property_id,
          a.r_e,
          a.description,
          a.amount,
          a.notes,
          a.record_date,
          a.created_at,
          a.updated_at
        ]
      end
    end

    send_data csv,
      filename: "accountings-#{Time.zone.now.strftime('%Y-%m-%d_%H%M')}.csv",
      type: "text/csv"
  end

  # POST /accountings/import_csv
  def import_csv
    file = params[:file]
    unless file&.respond_to?(:read)
      redirect_to accountings_path, alert: "Please choose a CSV file to upload."
      return
    end

    rows = []
    CSV.foreach(file.path, headers: true) { |row| rows << row.to_h }

    # Upsert by id if present, otherwise create new rows.
    Accounting.transaction do
      rows.each_with_index do |h, idx|
        attrs = sanitize_csv_row(h)

        if attrs[:id].present?
          rec = Accounting.find_by(id: attrs[:id])
          if rec
            rec.update!(attrs.except(:id, :created_at, :updated_at))
          else
            Accounting.create!(attrs.except(:created_at, :updated_at))
          end
        else
          Accounting.create!(attrs.except(:id, :created_at, :updated_at))
        end
      rescue ActiveRecord::RecordInvalid => e
        raise ActiveRecord::Rollback, "Row #{idx + 1}: #{e.record.errors.full_messages.join(', ')}"
      end
    end

    redirect_to accountings_path, notice: "Import complete (#{rows.size} rows processed)."
  rescue => e
    redirect_to accountings_path, alert: "Import failed: #{e.message}"
  end




  def index
    @search = Search.new

# All Possible Criterias 
    params['property'].present? ? property = params['property'] : property = 1..100
    params['description'].present? ? description = params['description'] : description = AccountingList.pluck(:accounting_type)
    params['r_e'].present? ? r_e = params['r_e'] : r_e = ['Revenue', 'Expense']
    params['date_range_a'].present? ? date_range_a = params['date_range_a'] : date_range_a = '2000-01-01'
    params['date_range_b'].present? ? date_range_b = params['date_range_b'] : date_range_b = '2150-01-01'

    @accountings = Accounting.where(property_id: property).where(description: description).where(r_e: r_e).where(record_date: date_range_a .. date_range_b).order(record_date: :DESC).all
    @accountings_sum = @accountings.sum(:amount)
    @accountings_count = @accountings.count
  end

  # GET /accountings/1 or /accountings/1.json
  def show
  end

  # GET /accountings/new
  def new
    @accounting = Accounting.new
  end

  # GET /accountings/1/edit
  def edit
  end

  # POST /accountings or /accountings.json
  def create
    @accounting = Accounting.new(accounting_params)

    respond_to do |format|
      if @accounting.save
        # redirect_to pages_manage_property_path(property: @accounting.id)
        format.html { redirect_to pages_manage_property_path(property: @accounting.property_id), notice: "Accounting was successfully created." }
        format.json { render :show, status: :created, location: @accounting }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @accounting.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /accountings/1 or /accountings/1.json
  def update
    respond_to do |format|
      if @accounting.update(accounting_params)
        format.html { redirect_to accounting_url(@accounting), notice: "Accounting was successfully updated." }
        format.json { render :show, status: :ok, location: @accounting }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @accounting.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /accountings/1 or /accountings/1.json
  def destroy
    @accounting.destroy

    respond_to do |format|
      format.html { redirect_to accountings_url, notice: "Accounting was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_accounting
      @accounting = Accounting.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def accounting_params
      params.require(:accounting).permit(:property_id, :r_e, :description, :amount, :notes, :record_date)
    end

  def csv_headers
    %w[
      id
      property_id
      r_e
      description
      amount
      notes
      record_date
      created_at
      updated_at
    ]
  end

  # Accepts strings from CSV and casts to the right Ruby types.
  def sanitize_csv_row(h)
    {
      id:          h["id"].presence,
      property_id: h["property_id"].presence&.to_i,
      r_e:         h["r_e"].to_s.presence,
      description: h["description"].to_s.presence,
      amount:      h["amount"].presence && BigDecimal(h["amount"].to_s),
      notes:       h["notes"].to_s,
      record_date: h["record_date"].presence && Date.parse(h["record_date"].to_s),
      created_at:  h["created_at"].presence && Time.zone.parse(h["created_at"].to_s),
      updated_at:  h["updated_at"].presence && Time.zone.parse(h["updated_at"].to_s)
    }
  end
end
