class Portfolio::PropertiesController < Portfolio::BaseController
  before_action :set_property, only: %i[show edit update destroy]

  def index
    @properties = Portfolio::Property.ordered.includes(:projects)
  end

  def show
    @projects = @property.projects.by_date.includes(:expenses, :work_items, photos: { image_attachment: :blob })
  end

  def new
    @property = Portfolio::Property.new
  end

  def edit; end

  def create
    @property = Portfolio::Property.new(property_params)
    if @property.save
      redirect_to portfolio_property_path(@property), notice: "Property added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @property.update(property_params)
      redirect_to portfolio_property_path(@property), notice: "Property updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @property.destroy
    redirect_to portfolio_properties_path, notice: "Property removed."
  end

  def export_csv
    headers = %w[id name address property_type status acquired_on sold_on notes]
    rows = Portfolio::Property.ordered.map { |p| headers.map { |h| p.public_send(h) } }
    send_csv("properties", headers, rows)
  end

  private

  def set_property
    @property = Portfolio::Property.find(params[:id])
  end

  def property_params
    params.require(:portfolio_property).permit(:name, :address, :property_type, :acquired_on, :sold_on, :status, :notes, :position, :cover_photo)
  end
end
