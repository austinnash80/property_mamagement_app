class AccountingListsController < ApplicationController
  before_action :set_accounting_list, only: %i[ show edit update destroy ]

  # GET /accounting_lists or /accounting_lists.json

  require "csv"

  # GET /accounting_lists/export_csv
  def export_csv
    csv = CSV.generate(headers: true) do |out|
      out << csv_headers

      AccountingList.find_each do |a|
        out << [
          a.id,
          a.accounting_type,
          a.vendor,
          a.amount,
          a.notes,
          a.created_at,
          a.updated_at
        ]
      end
    end

    send_data csv,
      filename: "accounting-lists-#{Time.zone.now.strftime('%Y-%m-%d_%H%M')}.csv",
      type: "text/csv"
  end

  # POST /accounting_lists/import_csv
  def import_csv
    file = params[:file]
    unless file&.respond_to?(:read)
      redirect_to accounting_lists_path, alert: "Please choose a CSV file."
      return
    end

    rows = []
    CSV.foreach(file.path, headers: true) { |row| rows << row.to_h }

    AccountingList.transaction do
      rows.each_with_index do |h, idx|
        attrs = sanitize_csv_row(h)

        if attrs[:id].present?
          rec = AccountingList.find_by(id: attrs[:id])

          if rec
            rec.update!(attrs.except(:id, :created_at, :updated_at))
          else
            AccountingList.create!(attrs.except(:created_at, :updated_at))
          end
        else
          AccountingList.create!(attrs.except(:id, :created_at, :updated_at))
        end

      rescue ActiveRecord::RecordInvalid => e
        raise ActiveRecord::Rollback,
          "Row #{idx + 1}: #{e.record.errors.full_messages.join(', ')}"
      end
    end

    redirect_to accounting_lists_path, notice: "Import complete (#{rows.size} rows processed)."
  rescue => e
    redirect_to accounting_lists_path, alert: "Import failed: #{e.message}"
  end

  def index
    @accounting_lists = AccountingList.all
  end

  # GET /accounting_lists/1 or /accounting_lists/1.json
  def show
  end

  # GET /accounting_lists/new
  def new
    @accounting_list = AccountingList.new
  end

  # GET /accounting_lists/1/edit
  def edit
  end

  # POST /accounting_lists or /accounting_lists.json
  def create
    @accounting_list = AccountingList.new(accounting_list_params)

    respond_to do |format|
      if @accounting_list.save
        format.html { redirect_to accounting_list_url(@accounting_list), notice: "Accounting list was successfully created." }
        format.json { render :show, status: :created, location: @accounting_list }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @accounting_list.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /accounting_lists/1 or /accounting_lists/1.json
  def update
    respond_to do |format|
      if @accounting_list.update(accounting_list_params)
        format.html { redirect_to accounting_list_url(@accounting_list), notice: "Accounting list was successfully updated." }
        format.json { render :show, status: :ok, location: @accounting_list }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @accounting_list.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /accounting_lists/1 or /accounting_lists/1.json
  def destroy
    @accounting_list.destroy

    respond_to do |format|
      format.html { redirect_to accounting_lists_url, notice: "Accounting list was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_accounting_list
      @accounting_list = AccountingList.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def accounting_list_params
      params.require(:accounting_list).permit(:accounting_type, :vendor, :amount, :notes)
    end

      def csv_headers
    %w[
      id
      accounting_type
      vendor
      amount
      notes
      created_at
      updated_at
    ]
  end

  def sanitize_csv_row(h)
    {
      id:              h["id"].presence,
      accounting_type: h["accounting_type"].to_s.presence,
      vendor:          h["vendor"].to_s.presence,
      amount:          h["amount"].presence && BigDecimal(h["amount"].to_s),
      notes:           h["notes"].to_s,
      created_at:      h["created_at"].presence && Time.zone.parse(h["created_at"].to_s),
      updated_at:      h["updated_at"].presence && Time.zone.parse(h["updated_at"].to_s)
    }
  end
end
