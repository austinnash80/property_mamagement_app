class AccountingsController < ApplicationController
  before_action :set_accounting, only: %i[ show edit update destroy ]

  # GET /accountings or /accountings.json
  def index
    if params['property'].present? && params['description'].present?
      @accountings = Accounting.where(property_id: params['property']).where(description: params['description']).order(record_date: :DESC).all
    elsif params['property'].present? && params['r_e'].present?
      @accountings = Accounting.where(property_id: params['property']).where(r_e: params['r_e']).order(record_date: :DESC).all
    else
      @accountings = Accounting.order(record_date: :DESC).all
    end
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
