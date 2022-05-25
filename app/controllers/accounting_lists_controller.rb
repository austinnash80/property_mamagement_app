class AccountingListsController < ApplicationController
  before_action :set_accounting_list, only: %i[ show edit update destroy ]

  # GET /accounting_lists or /accounting_lists.json
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
end
