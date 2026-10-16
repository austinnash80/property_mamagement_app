# Austin: the facts kept for Austin — doctor numbers, addresses, school details.
# One page grouped by section; new entries go in through a modal on the same page.
class Family::AustinEntriesController < Family::BaseController
  before_action :set_entry, only: %i[edit update destroy]

  def index
    load_index
    @entry = Family::AustinEntry.new(section: params[:section].presence || "Other")
  end

  def new
    @entry = Family::AustinEntry.new(section: params[:section].presence || "Other")
  end

  def edit; end

  def create
    @entry = Family::AustinEntry.new(entry_params.merge(updated_by: current_user))
    if @entry.save
      # Title only: the value is often a code, a password or a health detail,
      # and notifications can show on a locked phone.
      notify_others_about("note for Austin", @entry.title, url: family_austin_entries_path)
      redirect_to family_austin_entries_path, notice: "Saved."
    else
      load_index
      @open_form = true # reopen the add modal so the errors are visible
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @entry.update(entry_params.merge(updated_by: current_user))
      redirect_to family_austin_entries_path, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entry.destroy
    redirect_to family_austin_entries_path, notice: "Deleted."
  end

  private

  def load_index
    @entries    = Family::AustinEntry.ordered.to_a
    @by_section = @entries.group_by(&:section)
  end

  def set_entry
    @entry = Family::AustinEntry.find(params[:id])
  end

  def entry_params
    params.require(:family_austin_entry).permit(:title, :section, :value, :notes)
  end
end
