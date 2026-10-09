# The Family App landing page: a card per feature, in the same shape as the
# property-management homepage. Features get added here one at a time.
class Family::DashboardController < Family::BaseController
  def index
    @open_count    = Family::Task.unfinished.count
    @mine_count    = current_user ? Family::Task.unfinished.where(assignee_id: current_user.id).count : 0
    @overdue_count = Family::Task.unfinished.where("due_on < ?", Family.today).count

    @next_event       = Family::Event.upcoming.first
    @events_this_week = Family::Event.overlapping(Family.today..(Family.today + 7)).count

    @reference_count = Family::Reference.count
    @note_count      = Family::Note.for_user(current_user).count
    @places_want     = Family::Place.want_to_go.count
    @places_been     = Family::Place.been.count
  end
end
