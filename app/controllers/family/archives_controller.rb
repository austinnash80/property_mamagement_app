class Family::ArchivesController < Family::BaseController
  def index
    @lists = Family::List.archived.ordered
    @tasks = Family::Task.archived.includes(:list, :assignee).order(updated_at: :desc)
  end
end
