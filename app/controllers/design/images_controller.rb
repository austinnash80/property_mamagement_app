class Design::ImagesController < Design::BaseController
  before_action :set_image, only: %i[show edit update destroy]

  def index
    @concepts = Design::Concept.ordered
    @images   = Design::Image.recent.includes(:concept).with_attached_file.search(params[:q])
    @images   = @images.where(category: params[:category])     if params[:category].present?
    @images   = @images.where(concept_id: params[:concept_id]) if params[:concept_id].present?
  end

  def show; end

  def new
    @image = Design::Image.new(concept_id: params[:concept_id])
  end

  def edit; end

  # Bulk upload: one form submit can attach many files, each becoming its own record.
  def create
    files = Array(params.dig(:design_image, :files)).reject(&:blank?)
    attrs = image_params.except(:file)
    if files.empty?
      @image = Design::Image.new(attrs)
      @image.errors.add(:base, "Choose at least one image")
      return render :new, status: :unprocessable_entity
    end

    created = 0
    Design::Image.transaction do
      files.each do |f|
        image = Design::Image.new(attrs)
        image.file.attach(f)
        image.save!
        created += 1
      end
    end
    redirect_to after_create_path(attrs[:concept_id]), notice: "#{created} image#{'s' unless created == 1} uploaded."
  rescue ActiveRecord::RecordInvalid => e
    @image = Design::Image.new(attrs)
    @image.errors.add(:base, e.message)
    render :new, status: :unprocessable_entity
  end

  def update
    attrs = image_params
    attrs.delete(:file) if attrs[:file].blank?   # keep the current file unless a replacement was chosen
    if @image.update(attrs)
      redirect_to design_image_path(@image), notice: "Image updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    concept = @image.concept
    @image.destroy
    redirect_to (concept ? design_concept_path(concept, anchor: "images") : design_images_path), notice: "Image deleted."
  end

  private

  def set_image
    @image = Design::Image.find(params[:id])
  end

  def image_params
    params.require(:design_image).permit(:title, :caption, :category, :tags, :source, :concept_id, :position, :file)
  end

  def after_create_path(concept_id)
    concept_id.present? ? design_concept_path(concept_id, anchor: "images") : design_images_path
  end
end
