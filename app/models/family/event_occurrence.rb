require "delegate"

# A displayed occurrence delegates content to its series or saved override.
# Dates belong to the occurrence; no generated copies are saved to the database.
class Family::EventOccurrence < SimpleDelegator
  attr_reader :series, :original_on, :starts_on

  def initialize(event, series:, original_on:, starts_on:)
    super(event)
    @series, @original_on, @starts_on = series, original_on, starts_on
  end

  def last_day
    starts_on + (__getobj__.last_day - __getobj__.starts_on).to_i
  end

  def ends_on
    last_day if __getobj__.ends_on.present?
  end

  def days
    starts_on..last_day
  end

  def multi_day?
    last_day > starts_on
  end

  def past?
    last_day < Family.today
  end
end
