class AccountingsController < ApplicationController
  before_action :set_accounting, only: %i[ show edit update destroy ]

  # GET /accountings or /accountings.json
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
end
