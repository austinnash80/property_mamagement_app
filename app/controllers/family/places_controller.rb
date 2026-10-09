# Places to go. One page, filtered by what you want to see (still to try, been,
# favourites) and by kind.
class Family::PlacesController < Family::BaseController
  before_action :set_place, only: %i[show edit update destroy visit favorite]

  VIEWS = %w[want been favorites all].freeze

  def index
    @view = VIEWS.include?(params[:view]) ? params[:view] : "want"
    @kind = params[:kind].presence

    scope = Family::Place.ordered.of_kind(@kind)
    @places = case @view
              when "been"      then scope.been.reorder(visited_at: :desc)
              when "favorites" then scope.favorites
              when "all"       then scope
              else                  scope.want_to_go
              end

    @counts = {
      "want"      => Family::Place.want_to_go.count,
      "been"      => Family::Place.been.count,
      "favorites" => Family::Place.favorites.count,
      "all"       => Family::Place.count
    }
    # Only offer kinds actually in use, so the filter row stays short.
    @kinds = Family::Place.group(:kind).count
    @place = Family::Place.new(kind: @kind || "restaurant")
  end

  def show; end

  def new
    @place = Family::Place.new(kind: params[:kind].presence || "restaurant")
  end

  def edit; end

  def create
    @place = Family::Place.new(place_params.merge(created_by: current_user))
    if @place.save
      notify_others_about("place to go", @place.name, url: family_place_path(@place),
                          detail: [@place.kind_label, @place.area.presence].compact.join(", "))
      redirect_to family_places_path(view: params[:view], kind: params[:kind]), notice: "Added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @place.update(place_params)
      redirect_to family_place_path(@place), notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @place.destroy
    redirect_to family_places_path, notice: "Deleted."
  end

  # Been there / not yet.
  def visit
    @place.visited? ? @place.mark_unvisited! : @place.mark_visited!
    redirect_back fallback_location: family_places_path
  end

  def favorite
    @place.update(favorite: !@place.favorite)
    redirect_back fallback_location: family_places_path
  end

  private

  def set_place
    @place = Family::Place.find(params[:id])
  end

  def place_params
    params.require(:family_place).permit(:name, :kind, :area, :url, :notes, :favorite)
  end
end
