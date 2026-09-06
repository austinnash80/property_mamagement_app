class Portfolio::ProjectsController < Portfolio::BaseController
  before_action :set_project, only: %i[show edit update destroy]

  def index
    @projects = Portfolio::Project.by_date.includes(:property, :expenses, :work_items)
    @projects = @projects.where(property_id: params[:property_id]) if params[:property_id].present?
  end

  def show
    @work_items = @project.work_items.includes(:vendor)
    @expenses   = @project.expenses.includes(:vendor, :work_item, receipts_attachments: :blob)
    @photos     = @project.photos.includes(:work_item, image_attachment: :blob)
    @documents  = @project.documents.includes(file_attachment: :blob)
  end

  def new
    @project = Portfolio::Project.new(property_id: params[:property_id])
  end

  def edit; end

  def create
    @project = Portfolio::Project.new(project_params)
    if @project.save
      redirect_to portfolio_project_path(@project), notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @project.update(project_params)
      redirect_to portfolio_project_path(@project), notice: "Project updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    property = @project.property
    @project.destroy
    redirect_to portfolio_property_path(property), notice: "Project deleted."
  end

  def export_csv
    headers = %w[id property title summary started_on completed_on status permit_number total_cost trades]
    rows = Portfolio::Project.by_date.includes(:property, :work_items).map do |p|
      [p.id, p.property.name, p.title, p.summary, p.started_on, p.completed_on, p.status, p.permit_number, p.total_cost, p.trades.join("; ")]
    end
    send_csv("projects", headers, rows)
  end

  private

  def set_project
    @project = Portfolio::Project.find(params[:id])
  end

  def project_params
    params.require(:portfolio_project).permit(:property_id, :title, :summary, :description, :started_on, :completed_on, :status, :permit_number, :permit_notes, :notes, :position)
  end
end
