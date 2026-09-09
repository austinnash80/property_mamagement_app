class Design::ConceptsController < Design::BaseController
  before_action :set_concept, only: %i[show edit update destroy]

  def index
    @concepts = Design::Concept.ordered.includes(images: { file_attachment: :blob })
  end

  def show
    @notes  = @concept.notes
    @images = @concept.images.with_attached_file
    @plans  = @concept.floor_plans.with_attached_thumbnail
  end

  def new
    @concept = Design::Concept.new
  end

  def edit; end

  def create
    @concept = Design::Concept.new(concept_params)
    if @concept.save
      redirect_to design_concept_path(@concept), notice: "Concept created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @concept.update(concept_params)
      redirect_to design_concept_path(@concept), notice: "Concept updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @concept.destroy
    redirect_to design_concepts_path, notice: "Concept deleted. Its notes and images were kept and are now unassigned."
  end

  private

  def set_concept
    @concept = Design::Concept.find(params[:id])
  end

  def concept_params
    params.require(:design_concept).permit(:title, :kind, :status, :location, :summary, :description, :position)
  end
end
