# Household reference: the facts you keep re-looking-up. Search first; "View all"
# lists the lot; new entries go in through a modal on the same page.
class Family::ReferencesController < Family::BaseController
  before_action :set_reference, only: %i[edit update destroy toggle_pin]

  def index
    load_index
    @reference = Family::Reference.new(category: params[:category].presence || "Other")
  end

  def new
    @reference = Family::Reference.new(category: params[:category].presence || "Other")
  end

  def edit; end

  def create
    @reference = Family::Reference.new(reference_params.merge(updated_by: current_user))
    if @reference.save
      notify_others_about("reference entry", @reference.title, url: family_references_path,
                          detail: @reference.value.presence)
      redirect_to family_references_path, notice: "Saved."
    else
      load_index
      @open_form = true # reopen the add modal so the errors are visible
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @reference.update(reference_params.merge(updated_by: current_user))
      redirect_to family_references_path, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @reference.destroy
    redirect_to family_references_path, notice: "Deleted."
  end

  def toggle_pin
    @reference.update(pinned: !@reference.pinned)
    redirect_back fallback_location: family_references_path
  end

  private

  # Every entry goes into the page so the search box can filter as you type; the
  # server only decides which are visible on first paint (and without JS).
  def load_index
    @q        = params[:q].presence
    @show_all = params[:all].present?
    @entries  = Family::Reference.ordered.to_a
    @total    = @entries.size
    @visible  =
      if @q         then @entries.select { |e| e.matches?(@q) }
      elsif @show_all then @entries
      else               @entries.select(&:pinned)
      end
  end

  def set_reference
    @reference = Family::Reference.find(params[:id])
  end

  def reference_params
    params.require(:family_reference).permit(:title, :category, :value, :notes, :pinned)
  end
end
