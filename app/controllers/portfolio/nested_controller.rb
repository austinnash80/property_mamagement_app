# Common behaviour for resources that live inside a project (work items,
# expenses, photos, documents). Routes are shallow: new/create are nested under
# the project, edit/update/destroy are top-level.
class Portfolio::NestedController < Portfolio::BaseController
  before_action :set_project, only: %i[new create]
  before_action :set_record,  only: %i[edit update destroy]

  def new
    @record = model.new(project: @project)
  end

  def edit; end

  def create
    @record = model.new(record_params.merge(project: @project))
    if @record.save
      redirect_to portfolio_project_path(@project, anchor: anchor), notice: "#{human_name} added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @record.update(record_params)
      redirect_to portfolio_project_path(@record.project, anchor: anchor), notice: "#{human_name} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    project = @record.project
    @record.destroy
    redirect_to portfolio_project_path(project, anchor: anchor), notice: "#{human_name} deleted."
  end

  private

  def set_project
    @project = Portfolio::Project.find(params[:project_id])
  end

  def set_record
    @record  = model.find(params[:id])
    @project = @record.project
  end

  def human_name
    model.model_name.human
  end

  def anchor
    model.model_name.plural.sub("portfolio_", "")
  end
end
