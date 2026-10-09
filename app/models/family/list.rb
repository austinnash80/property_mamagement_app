class Family::List < ApplicationRecord
  has_many :tasks, class_name: "Family::Task", foreign_key: :list_id, dependent: :destroy

  validates :name, presence: true
  validates :color, presence: true

  scope :ordered, -> { order(:position, :name) }

  before_validation { self.position = (Family::List.maximum(:position) || 0) + 1 if position.blank? || position.zero? }

  def open_count
    tasks.open.size
  end
end
