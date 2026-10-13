class Family::ListsController < Family::BaseController
  before_action :set_list, only: %i[edit update destroy restore]

  def index
    @lists = Family::List.active.ordered
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
      @lists = Family::List.active.ordered
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

  # Retain every task, including its notes, assignment and completion history.
  def destroy
    @list.archive!
    redirect_to family_lists_path, notice: "List archived with its tasks. You can restore it from Archived work."
  end

  def restore
    @list.restore!
    redirect_to family_archive_path, notice: "List restored. Tasks archived separately stay archived."
  end

  private

  def set_list
    scope = %w[destroy restore].include?(action_name) ? Family::List.all : Family::List.active
    @list = scope.find(params[:id])
  end

  def list_params
    params.require(:family_list).permit(:name, :color, :position)
  end
end
