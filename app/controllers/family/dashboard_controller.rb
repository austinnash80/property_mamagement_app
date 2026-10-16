# The Family App landing page: a card per feature, in the same shape as the
# property-management homepage. Features get added here one at a time.
class Family::DashboardController < Family::BaseController
  def index
    @open_count    = Family::Task.active.unfinished.count
    @mine_count    = current_user ? Family::Task.active.unfinished.where(assignee_id: current_user.id).count : 0

    @next_event       = Family::Event.upcoming_occurrences(limit: 1).first
    @events_this_week = Family::Event.occurrences_between(Family.today..(Family.today + 7)).count

    @reference_count = Family::Reference.count
    @andie_count     = Family::AndieEntry.count
    @rae_count       = Family::RaeEntry.count
    @note_count      = Family::Note.for_user(current_user).count
    @places_want     = Family::Place.want_to_go.count
    @places_been     = Family::Place.been.count
  end
end
