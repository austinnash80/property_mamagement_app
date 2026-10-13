class Family::List < ApplicationRecord
  has_many :tasks, class_name: "Family::Task", foreign_key: :list_id, dependent: :destroy

  validates :name, presence: true
  validates :color, presence: true

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def archive!
    update!(archived_at: archived_at || Time.current)
  end

  def restore!
    update!(archived_at: nil)
  end

  scope :ordered, -> { order(:position, :name) }

  before_validation { self.position = (Family::List.maximum(:position) || 0) + 1 if position.blank? || position.zero? }

  def open_count
    tasks.active.unfinished.size
  end
end
