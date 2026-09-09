class Design::Concept < ApplicationRecord
  has_many :notes,  -> { order(pinned: :desc, updated_at: :desc) }, class_name: "Design::Note",  dependent: :nullify
  has_many :images, -> { order(:position, :created_at) },          class_name: "Design::Image", dependent: :nullify
  has_many :floor_plans, -> { order(:position, :id) },                class_name: "Design::FloorPlan", dependent: :destroy

  validates :title,  presence: true
  validates :kind,   inclusion: { in: Design::CONCEPT_KINDS }
  validates :status, inclusion: { in: Design::CONCEPT_STATUSES }

  scope :ordered, -> { order(:position, :title) }

  def cover
    images.first
  end
end
