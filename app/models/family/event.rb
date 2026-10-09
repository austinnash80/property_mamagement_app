class Family::Event < ApplicationRecord
  belongs_to :person,     class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :title, presence: true
  validates :starts_on, presence: true
  validate  :ends_on_after_starts_on

  scope :ordered,   -> { order(:starts_on, Arel.sql("start_time ASC NULLS FIRST"), :title) }
  scope :upcoming,  -> { where("COALESCE(ends_on, starts_on) >= ?", Family.today).ordered }
  # Anything touching this range, multi-day events included.
  scope :overlapping, ->(range) {
    where("starts_on <= :last AND COALESCE(ends_on, starts_on) >= :first",
          first: range.first, last: range.last).ordered
  }

  def last_day
    ends_on.presence || starts_on
  end

  def multi_day?
    last_day > starts_on
  end

  def days
    (starts_on..last_day)
  end

  def all_day?
    start_time.blank?
  end

  def past?
    last_day < Family.today
  end

  # "All day", "7:00 PM", or "7:00 PM – 9:00 PM"
  def time_label
    return "All day" if all_day?
    [fmt(start_time), fmt(end_time)].compact.join(" – ")
  end

  # Compact form for the month grid, where space is tight: "7p", "7:30p".
  def short_time
    return nil if all_day?
    start_time.strftime(start_time.min.zero? ? "%-l%P" : "%-l:%M%P").sub("am", "a").sub("pm", "p")
  end

  private

  def fmt(t)
    t&.strftime("%-l:%M %p")
  end

  def ends_on_after_starts_on
    return if ends_on.blank? || starts_on.blank?
    errors.add(:ends_on, "can't be before the start date") if ends_on < starts_on
  end
end
