# The private scratchpad. Every query - index, edit, update, destroy - runs
# through #scope, which is pinned to the signed-in user, so one member can never
# reach another's notes, not even by guessing an id.
class Family::NotesController < Family::BaseController
  before_action :set_note, only: %i[edit update destroy]

  def index
    @notes = scope.ordered
    @note  = Family::Note.new
  end

  def new
    @note = Family::Note.new
  end

  def edit; end

  # Quick-add from the index sends a title only: start the note and open it.
  def create
    @note = scope.new(note_params)
    if @note.save
      redirect_to edit_family_note_path(@note), notice: "Note started."
    else
      @notes = scope.ordered
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @note.update(note_params)
      redirect_to family_notes_path, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @note.destroy
    redirect_to family_notes_path, notice: "Deleted."
  end

  private

  def scope
    Family::Note.for_user(current_user)
  end

  # find on the user-scoped relation: someone else's id raises RecordNotFound
  # rather than loading the note.
  def set_note
    @note = scope.find(params[:id])
  end

  def note_params
    params.require(:family_note).permit(:title, :body)
  end
end
