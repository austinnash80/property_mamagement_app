class Family::ListsController < Family::BaseController
  before_action :set_list, only: %i[edit update destroy]

  def index
    @lists = Family::List.ordered
    @list  = Family::List.new
  end

  def new
    @list = Family::List.new
  end

  def edit; end

  def create
    @list = Family::List.new(list_params)
    if @list.save
      redirect_to family_lists_path, notice: "List created."
    else
      @lists = Family::List.ordered
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @list.update(list_params)
      redirect_to family_lists_path, notice: "List updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Deleting a list takes its tasks with it, so say how many first.
  def destroy
    count = @list.tasks.count
    @list.destroy
    redirect_to family_lists_path, notice: "List deleted#{" with #{count} #{'task'.pluralize(count)}" if count > 0}."
  end

  private

  def set_list
    @list = Family::List.find(params[:id])
  end

  def list_params
    params.require(:family_list).permit(:name, :color, :position)
  end
end
