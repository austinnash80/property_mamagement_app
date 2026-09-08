class Design::NotesController < Design::BaseController
  before_action :set_note, only: %i[show edit update destroy toggle_pin]

  def index
    @concepts = Design::Concept.ordered
    @notes    = Design::Note.recent.includes(:concept).search(params[:q])
    @notes    = @notes.where(concept_id: params[:concept_id]) if params[:concept_id].present?
  end

  def show; end

  def new
    @note = Design::Note.new(concept_id: params[:concept_id])
  end

  def edit; end

  def create
    @note = Design::Note.new(note_params)
    if @note.save
      redirect_to after_save_path, notice: "Note saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @note.update(note_params)
      redirect_to design_note_path(@note), notice: "Note updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    concept = @note.concept
    @note.destroy
    redirect_to (concept ? design_concept_path(concept, anchor: "notes") : design_notes_path), notice: "Note deleted."
  end

  def toggle_pin
    @note.update(pinned: !@note.pinned)
    redirect_back fallback_location: design_notes_path, notice: (@note.pinned ? "Note pinned." : "Note unpinned.")
  end

  private

  def set_note
    @note = Design::Note.find(params[:id])
  end

  def note_params
    params.require(:design_note).permit(:title, :body, :tags, :pinned, :concept_id)
  end

  # The quick-capture form on the index returns to the list; the full form goes
  # to the concept (if any) or the new note.
  def after_save_path
    return design_notes_path if params[:quick].present?
    @note.concept ? design_concept_path(@note.concept, anchor: "notes") : design_note_path(@note)
  end
end
