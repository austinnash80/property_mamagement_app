class Family::TasksController < Family::BaseController
  before_action :set_task, only: %i[show edit update destroy toggle]

  # /family/todo — the to-do overview: one card per list, showing the first few
  # open tasks on it. The card links to that list's own page, where everything
  # is listed in full.
  PREVIEW = 5

  def overview
    @lists = Family::List.ordered
    @open_by_list = Family::Task.unfinished.ordered.group_by(&:list_id)
    @task = Family::Task.new(list: @lists.first)
  end

  # The task list itself, filtered by whichever view was picked on the overview:
  # `list`, `tag` or `person` (an id, or "none" for unassigned).
  def index
    @lists  = Family::List.ordered
    @list   = @lists.find_by(id: params[:list]) if params[:list].present?
    @people = User.by_name
    @tag    = params[:tag].presence
    @person = User.find_by(id: params[:person]) if params[:person].present?
    @unassigned_only = params[:person] == "none"

    scope = Family::Task.includes(:list, :assignee)
    scope = scope.where(list_id: @list.id)   if @list
    scope = scope.where(assignee_id: nil)    if @unassigned_only
    scope = scope.where(assignee_id: @person.id) if @person
    scope = scope.tagged(@tag)

    @open    = scope.unfinished.ordered
    @done    = scope.recently_done.limit(15)
    @task    = Family::Task.new(list: @list || @lists.first, tags: @tag, assignee: @person)
  end

  def show
    @people = User.by_name
  end

  def new
    form_options
    @task = Family::Task.new(list_id: params[:list], tags: params[:tag])
  end

  def edit
    form_options
  end

  def create
    @task = Family::Task.new(task_params.merge(created_by: current_user))
    if @task.save
      notify_others_about("task", @task.title, url: family_task_path(@task),
                          detail: [@task.list.name, (@task.assignee && "for #{@task.assignee.display_name}")].compact.join(", "))
      redirect_to after_save_path, notice: "Task added."
    else
      form_options
      if params[:quick].present?
        @open, @done = Family::Task.none, Family::Task.none
        render :index, status: :unprocessable_entity
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def update
    if @task.update(task_params)
      # The note box on the detail page posts here too; stay on the page it
      # came from rather than bouncing back to the list.
      redirect_to (params[:stay].present? ? family_task_path(@task) : family_tasks_path(list: @task.list_id)),
                  notice: (params[:stay].present? ? "Note saved." : "Task updated.")
    else
      form_options
      render (params[:stay].present? ? :show : :edit), status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy
    redirect_back fallback_location: current_view_path, notice: "Task deleted."
  end

  # Check off / un-check. Shared list: anyone may toggle anyone's task, but the
  # task records who did it.
  def toggle
    @task.done? ? @task.reopen! : @task.complete!(current_user)
    redirect_back fallback_location: current_view_path
  end

  private

  def set_task
    @task = Family::Task.find(params[:id])
  end

  # The view the row was checked off from, so a missing Referer still lands you
  # back where you were rather than on the unfiltered list.
  def current_view_path
    family_tasks_path(list: params[:list].presence, tag: params[:tag].presence, person: params[:person].presence)
  end

  def form_options
    @lists  = Family::List.ordered
    @people = User.by_name
    @tags   = Family::Task.all_tags
  end

  def task_params
    params.require(:family_task).permit(:list_id, :title, :notes, :tags, :assignee_id)
  end

  # Quick-add keeps you where you were: on the overview, or in the view you
  # were looking at.
  def after_save_path
    return family_todo_path if params[:from] == "overview"
    family_tasks_path(list: params[:list].presence, tag: params[:tag].presence, person: params[:person].presence)
  end
end
