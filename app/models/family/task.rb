class Family::Task < ApplicationRecord
  belongs_to :list, class_name: "Family::List", foreign_key: :list_id
  belongs_to :assignee, class_name: "User", optional: true
  belongs_to :done_by,    class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :title, presence: true

  scope :open,      -> { where(done_at: nil) }
  scope :done,      -> { where.not(done_at: nil) }
  scope :ordered,   -> { order(Arel.sql("due_on ASC NULLS LAST"), position: :asc, created_at: :asc) }
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
    (Family::SUGGESTED_TAGS + where.not(tags: [nil, ""]).pluck(:tags).flat_map { |t| Family.tag_list(t) })
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

  def overdue?
    due_on.present? && !done? && due_on < Family.today
  end

  # Which section of the list this task belongs under.
  def bucket
    today = Family.today
    return :none    if due_on.blank?
    return :overdue if due_on < today
    return :today   if due_on == today
    return :week    if due_on <= today.end_of_week
    :later
  end
end
