class SearchesController < ApplicationController
  before_action :set_search, only: %i[ show edit update destroy ]

  # GET /searches or /searches.json
  def index
    @searches = Search.all
  end

  # GET /searches/1 or /searches/1.json
  def show
  end

  # GET /searches/new
  def new
    @search = Search.new
  end

  # GET /searches/1/edit
  def edit
  end

  # POST /searches or /searches.json
  def create
    @search = Search.new(search_params)

    respond_to do |format|
      if @search.save
        property_id = Property.find_by(nickname: @search.property)
        format.html { redirect_to accountings_path(search: 'yes', property: property_id.id, r_e: @search.accounting_type, description: @search.description, date_range_a: @search.date_range_a.present? ? @search.date_range_a : Date.today, date_range_b: @search.date_range_b.present? ? @search.date_range_b : Date.today), notice: "" }
        # format.html { redirect_to search_url(@search), notice: "Search was successfully created." }
        format.json { render :show, status: :created, location: @search }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @search.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /searches/1 or /searches/1.json
  def update
    respond_to do |format|
      if @search.update(search_params)
        format.html { redirect_to search_url(@search), notice: "Search was successfully updated." }
        format.json { render :show, status: :ok, location: @search }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @search.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /searches/1 or /searches/1.json
  def destroy
    @search.destroy

    respond_to do |format|
      format.html { redirect_to searches_url, notice: "Search was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_search
      @search = Search.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def search_params
      params.require(:search).permit(:property, :accounting_type, :description, :date_range_a, :date_range_b, :field_1, :field_2, :field_3)
    end
end
