class Portfolio::PhotosController < Portfolio::NestedController
  # Bulk upload: one form submit can attach many images, each becoming its own photo record.
  def create
    images = Array(params.dig(:portfolio_photo, :images)).reject(&:blank?)
    attrs  = record_params
    if images.empty?
      @record = model.new(attrs.merge(project: @project))
      @record.errors.add(:image, "choose at least one image")
      return render :new, status: :unprocessable_entity
    end

    created = 0
    model.transaction do
      images.each do |img|
        photo = model.new(attrs.merge(project: @project))
        photo.image.attach(img)
        photo.save!
        created += 1
      end
    end
    redirect_to portfolio_project_path(@project, anchor: "photos"), notice: "#{created} photo#{'s' unless created == 1} added."
  rescue ActiveRecord::RecordInvalid => e
    @record = model.new(attrs.merge(project: @project))
    @record.errors.add(:base, e.message)
    render :new, status: :unprocessable_entity
  end

  private

  def model = Portfolio::Photo

  def record_params
    params.require(:portfolio_photo).permit(:stage, :caption, :taken_on, :work_item_id, :position, :image)
  end
end
