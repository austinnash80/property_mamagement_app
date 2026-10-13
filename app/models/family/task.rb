class Family::Task < ApplicationRecord
  belongs_to :list, class_name: "Family::List", foreign_key: :list_id
  belongs_to :assignee, class_name: "User", optional: true
  belongs_to :done_by,    class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :title, presence: true
  validate :list_is_active, if: -> { new_record? || will_save_change_to_list_id? }

  # A list archive hides its tasks without changing their individual state.
  scope :active, -> { joins(:list).where(archived_at: nil, family_lists: { archived_at: nil }) }
  scope :archived, -> {
    joins(:list).where("family_tasks.archived_at IS NOT NULL OR family_lists.archived_at IS NOT NULL")
  }

  def archive!
    update!(archived_at: archived_at || Time.current)
  end

  def restore!
    update!(archived_at: nil)
  end

  def list_is_active
    errors.add(:list, "is archived; restore it before adding tasks") if list&.archived_at.present?
  end
  private :list_is_active

  scope :unfinished, -> { where(done_at: nil) }
  scope :done,      -> { where.not(done_at: nil) }
  scope :ordered,   -> { order(position: :asc, created_at: :asc) }
  scope :recently_done, -> { done.order(done_at: :desc) }
  scope :tagged, lambda { |tag|
    next all if tag.blank?
    where("tags ILIKE ?", "%#{sanitize_sql_like(tag)}%")
  }

  def tag_list
    Family.tag_list(tags)
  end

  # Every tag in use, plus the built-in suggestions, for the tag box.
  def self.all_tags
    (Family::SUGGESTED_TAGS + active.where.not(tags: [nil, ""]).pluck(:tags).flat_map { |t| Family.tag_list(t) })
      .uniq { |t| t.downcase }.sort_by(&:downcase)
  end

  def done?
    done_at.present?
  end

  # Checking a task off records who did it, so a shared list still has a trail.
  def complete!(user)
    update!(done_at: Time.current, done_by: user)
  end

  def reopen!
    update!(done_at: nil, done_by: nil)
  end
end
