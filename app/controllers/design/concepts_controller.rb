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

  # HTML from the edit form, or JSON from the 3D view saving its render settings.
  def update
    attrs = concept_params.to_h
    if (rs = params.dig(:design_concept, :render_settings)).is_a?(ActionController::Parameters)
      attrs["render_settings"] = (@concept.render_settings || {}).merge(rs.permit(:roof, :exterior, :roofColor, :floor).to_h)
    end
    if @concept.update(attrs)
      respond_to do |f|
        f.html { redirect_to design_concept_path(@concept), notice: "Concept updated." }
        f.json { render json: { ok: true, render_settings: @concept.render_settings } }
      end
    else
      respond_to do |f|
        f.html { render :edit, status: :unprocessable_entity }
        f.json { render json: { ok: false, errors: @concept.errors.full_messages }, status: :unprocessable_entity }
      end
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
    params.fetch(:design_concept, {}).permit(:title, :kind, :status, :location, :summary, :description, :position)
  end
end
