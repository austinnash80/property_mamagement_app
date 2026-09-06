class Portfolio::VendorsController < Portfolio::BaseController
  before_action :set_vendor, only: %i[show edit update destroy]

  def index
    @vendors = Portfolio::Vendor.ordered
  end

  def show
    @projects = @vendor.projects.includes(:property).by_date
  end

  def new
    @vendor = Portfolio::Vendor.new
  end

  def edit; end

  def create
    @vendor = Portfolio::Vendor.new(vendor_params)
    if @vendor.save
      redirect_to portfolio_vendor_path(@vendor), notice: "Vendor added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @vendor.update(vendor_params)
      redirect_to portfolio_vendor_path(@vendor), notice: "Vendor updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @vendor.destroy
    redirect_to portfolio_vendors_path, notice: "Vendor removed."
  end

  def export_csv
    headers = %w[id name trade contact_name phone email website license_number notes]
    rows = Portfolio::Vendor.ordered.map { |v| headers.map { |h| v.public_send(h) } }
    send_csv("vendors", headers, rows)
  end

  private

  def set_vendor
    @vendor = Portfolio::Vendor.find(params[:id])
  end

  def vendor_params
    params.require(:portfolio_vendor).permit(:name, :trade, :contact_name, :phone, :email, :website, :license_number, :notes)
  end
end
