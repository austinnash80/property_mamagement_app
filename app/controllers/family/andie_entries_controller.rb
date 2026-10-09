# Andie: the facts kept for Andie — doctor numbers, addresses, school details.
# One page grouped by section; new entries go in through a modal on the same page.
class Family::AndieEntriesController < Family::BaseController
  before_action :set_entry, only: %i[edit update destroy]

  def index
    load_index
    @entry = Family::AndieEntry.new(section: params[:section].presence || "Other")
  end

  def new
    @entry = Family::AndieEntry.new(section: params[:section].presence || "Other")
  end

  def edit; end

  def create
    @entry = Family::AndieEntry.new(entry_params.merge(updated_by: current_user))
    if @entry.save
      notify_others_about("note for Andie", @entry.title, url: family_andie_entries_path,
                          detail: @entry.value.presence)
      redirect_to family_andie_entries_path, notice: "Saved."
    else
      load_index
      @open_form = true # reopen the add modal so the errors are visible
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @entry.update(entry_params.merge(updated_by: current_user))
      redirect_to family_andie_entries_path, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entry.destroy
    redirect_to family_andie_entries_path, notice: "Deleted."
  end

  private

  def load_index
    @entries    = Family::AndieEntry.ordered.to_a
    @by_section = @entries.group_by(&:section)
  end

  def set_entry
    @entry = Family::AndieEntry.find(params[:id])
  end

  def entry_params
    params.require(:family_andie_entry).permit(:title, :section, :value, :notes)
  end
end
