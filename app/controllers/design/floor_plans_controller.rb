class Design::FloorPlansController < Design::BaseController
  before_action :set_concept, only: %i[new create]
  before_action :set_plan,    only: %i[show edit update destroy]

  def index
    @plans = Design::FloorPlan.includes(:concept).with_attached_thumbnail.order(updated_at: :desc)
    @plans = @plans.where(concept_id: params[:concept_id]) if params[:concept_id].present?
  end

  # The editor.
  def show
    @plan_json = @plan.data_with_defaults
    # Other levels of the same concept, offered as a faint underlay in the editor.
    @siblings  = @concept.floor_plans.where.not(id: @plan.id).map { |p| { id: p.id, name: p.name, level: p.level, data: p.data_with_defaults } }
  end

  def new
    @plan = @concept.floor_plans.new(name: default_name)
  end

  def edit; end

  def create
    @plan = @concept.floor_plans.new(plan_params)
    if @plan.save
      redirect_to design_floor_plan_path(@plan), notice: "Floor plan created. Start drawing."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Two callers: the settings form (HTML) and the editor's save (JSON body with
  # the geometry and a PNG snapshot).
  def update
    attrs = plan_params
    if (raw = params.dig(:design_floor_plan, :data)).is_a?(ActionController::Parameters)
      attrs[:data] = raw.to_unsafe_h
    end

    if @plan.update(attrs)
      @plan.thumbnail_from_data_url(params.dig(:design_floor_plan, :thumbnail_data))
      respond_to do |f|
        f.json { render json: { ok: true, saved_at: @plan.updated_at.strftime("%-l:%M:%S %p"), rooms: @plan.rooms.size, area: @plan.total_area_sqft.round } }
        f.html { redirect_to design_floor_plan_path(@plan), notice: "Floor plan settings saved." }
      end
    else
      respond_to do |f|
        f.json { render json: { ok: false, errors: @plan.errors.full_messages }, status: :unprocessable_entity }
        f.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    concept = @plan.concept
    @plan.destroy
    redirect_to design_concept_path(concept, anchor: "plans"), notice: "Floor plan deleted."
  end

  private

  def set_concept
    @concept = Design::Concept.find(params[:concept_id])
  end

  def set_plan
    @plan    = Design::FloorPlan.find(params[:id])
    @concept = @plan.concept
  end

  def plan_params
    params.require(:design_floor_plan).permit(:name, :level, :width_ft, :depth_ft, :notes, :position)
  end

  def default_name
    n = @concept.floor_plans.count
    n.zero? ? "Main floor" : "Level #{n + 1}"
  end
end
