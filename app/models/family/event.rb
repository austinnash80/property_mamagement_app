class Family::Event < ApplicationRecord
  belongs_to :person,     class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true

  before_validation do
    self.title = title.strip if title
    self.repeat_until = nil unless repeating?
  end

  validates :title, presence: true
  validates :starts_on, presence: true
  validate  :ends_on_after_starts_on

  scope :ordered,   -> { order(:starts_on, Arel.sql("start_time ASC NULLS FIRST"), :title) }
  belongs_to :recurrence_parent, class_name: "Family::Event", optional: true
  has_many :recurrence_overrides, class_name: "Family::Event", foreign_key: :recurrence_parent_id,
           dependent: :destroy, inverse_of: :recurrence_parent

  validates :repeat_frequency, inclusion: { in: Family::EVENT_REPEAT_OPTIONS.values }
  validates :original_on, presence: true, uniqueness: { scope: :recurrence_parent_id }, if: :recurrence_parent_id?
  validate :valid_recurrence

  scope :series, -> { where(recurrence_parent_id: nil) }

  def repeating?
    repeat_frequency != "none"
  end

  def repeat_label
    Family::EVENT_REPEAT_OPTIONS.key(repeat_frequency)
  end

  # Expand only the requested window, with dates calculated from the original
  # anchor (Jan 31 -> Feb 28 -> Mar 31), never from the previous occurrence.
  def occurrence_dates(range, limit: nil)
    duration = (last_day - starts_on).to_i
    earliest = range.first - duration
    distance = case repeat_frequency
               when "daily" then (earliest - starts_on).to_i
               when "weekly" then (earliest - starts_on).to_i / 7
               when "monthly" then (earliest.year - starts_on.year) * 12 + earliest.month - starts_on.month
               when "annually" then earliest.year - starts_on.year
               else 0
               end
    index = [distance - 1, 0].max
    dates = []
    loop do
      day = case repeat_frequency
            when "daily" then starts_on + index
            when "weekly" then starts_on + index * 7
            when "monthly" then starts_on.advance(months: index)
            when "annually" then starts_on.advance(years: index)
            else starts_on
            end
      break if day > range.last || (repeat_until && day > repeat_until)
      dates << day if day + duration >= range.first
      break if !repeating? || (limit && dates.size >= limit)
      index += 1
    end
    dates
  end

  def occurrence_on(day)
    return unless occurrence_dates(day..day).include?(day)
    override = recurrence_overrides.find_by(original_on: day)
    return if override&.cancelled?
    Family::EventOccurrence.new(override || self, series: self, original_on: day,
                               starts_on: override ? override.starts_on : day)
  end

  def self.occurrences_between(range)
    series.includes(:person, recurrence_overrides: :person).flat_map do |event|
      overrides = event.recurrence_overrides.index_by(&:original_on)
      ordinary = event.occurrence_dates(range).filter_map do |day|
        Family::EventOccurrence.new(event, series: event, original_on: day, starts_on: day) unless overrides.key?(day)
      end
      changed = overrides.values.filter_map do |override|
        next if override.cancelled? || (event.repeat_until && override.original_on > event.repeat_until)
        next if override.starts_on > range.last || override.last_day < range.first
        Family::EventOccurrence.new(override, series: event, original_on: override.original_on, starts_on: override.starts_on)
      end
      ordinary + changed
    end.then { |events| sort_occurrences(events) }
  end

  def self.upcoming_occurrences(limit: 8)
    today = Family.today
    events = series.includes(:person, recurrence_overrides: :person).flat_map do |event|
      overrides = event.recurrence_overrides.index_by(&:original_on)
      # At most one ordinary occurrence can be hidden by each override.
      horizon = [today, event.starts_on].max.advance(years: limit + overrides.size + 1)
      ordinary = event.occurrence_dates(today..horizon, limit: limit + overrides.size).filter_map do |day|
        Family::EventOccurrence.new(event, series: event, original_on: day, starts_on: day) unless overrides.key?(day)
      end
      changed = overrides.values.filter_map do |override|
        next if override.cancelled? || (event.repeat_until && override.original_on > event.repeat_until)
        next if override.last_day < today
        Family::EventOccurrence.new(override, series: event, original_on: override.original_on, starts_on: override.starts_on)
      end
      ordinary + changed
    end
    sort_occurrences(events).first(limit)
  end

  def self.sort_occurrences(events)
    events.sort_by { |event| [event.starts_on, event.start_time&.strftime("%H:%M:%S") || "", event.title] }
  end

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

  def valid_recurrence
    if repeat_until.present? && starts_on.present? && repeat_until < starts_on
      errors.add(:repeat_until, "can't be before the start date")
    end
    if recurrence_parent_id.present? && (repeating? || original_on.blank?)
      errors.add(:base, "An individual occurrence cannot repeat")
    end
    if recurrence_parent_id.blank? && recurrence_overrides.any? &&
       (will_save_change_to_starts_on? || will_save_change_to_repeat_frequency?)
      errors.add(:base, "This series has individual changes. Keep its start date and repeat frequency, or delete the series and create a new one.")
    end
  end

  def fmt(t)
    t&.strftime("%-l:%M %p")
  end

  def ends_on_after_starts_on
    return if ends_on.blank? || starts_on.blank?
    errors.add(:ends_on, "can't be before the start date") if ends_on < starts_on
  end
end
