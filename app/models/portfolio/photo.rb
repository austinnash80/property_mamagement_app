class Portfolio::Photo < ApplicationRecord
  belongs_to :project,   class_name: "Portfolio::Project"
  belongs_to :work_item, class_name: "Portfolio::WorkItem", optional: true
  has_one_attached :image

  validates :stage, inclusion: { in: Portfolio::PHOTO_STAGES }
  validates :image, presence: true

  def thumb
    image.variant(resize_to_limit: [400, 400])
  end

  def large
    image.variant(resize_to_limit: [1600, 1600])
  end
end
