class Design::Image < ApplicationRecord
  belongs_to :concept, class_name: "Design::Concept", optional: true
  has_one_attached :file

  validates :file,     presence: true
  validates :category, inclusion: { in: Design::IMAGE_CATEGORIES }
  validate  :file_is_an_image

  scope :recent, -> { order(created_at: :desc) }
  scope :search, lambda { |q|
    next all if q.blank?
    like = "%#{sanitize_sql_like(q)}%"
    where("design_images.title ILIKE :q OR design_images.caption ILIKE :q OR design_images.tags ILIKE :q OR design_images.source ILIKE :q", q: like)
  }

  def display_title
    return title if title.present?
    file.attached? ? file.filename.base.to_s.tr("_-", " ") : "Untitled"
  end

  def tag_list
    Design.tag_list(tags)
  end

  def thumb
    file.variant(resize_to_limit: [500, 500])
  end

  def large
    file.variant(resize_to_limit: [2000, 2000])
  end

  private

  def file_is_an_image
    return unless file.attached?
    return if file.blob.content_type.to_s.start_with?("image/")
    errors.add(:file, "must be an image (JPEG, PNG, GIF, WebP, HEIC)")
  end
end
