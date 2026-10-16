require "test_helper"

class Family::EventTest < ActiveSupport::TestCase
  def event(**attributes)
    Family::Event.create!({ title: "Birthday", starts_on: Date.new(2020, 5, 12), repeat_frequency: "annually" }.merge(attributes))
  end

  test "annual events recur beyond their original year and never before the start" do
    birthday = event
    assert_equal [Date.new(2035, 5, 12)], birthday.occurrence_dates(Date.new(2035, 1, 1)..Date.new(2035, 12, 31))
    assert_empty birthday.occurrence_dates(Date.new(2019, 1, 1)..Date.new(2019, 12, 31))
  end

  test "daily and weekly events use the original interval" do
    day = Date.new(2026, 10, 16)
    assert_equal [day, day + 1, day + 2], event(starts_on: day, repeat_frequency: "daily").occurrence_dates(day..day + 2)
    assert_equal [day, day + 7, day + 14], event(starts_on: day, repeat_frequency: "weekly").occurrence_dates(day..day + 15)
  end

  test "month ends clamp without drifting and leap birthdays return to February 29" do
    monthly = event(starts_on: Date.new(2026, 1, 31), repeat_frequency: "monthly")
    assert_equal [Date.new(2026, 1, 31), Date.new(2026, 2, 28), Date.new(2026, 3, 31)],
                 monthly.occurrence_dates(Date.new(2026, 1, 1)..Date.new(2026, 3, 31))
    leap = event(starts_on: Date.new(2024, 2, 29))
    assert_equal [Date.new(2027, 2, 28), Date.new(2028, 2, 29)],
                 leap.occurrence_dates(Date.new(2027, 1, 1)..Date.new(2028, 12, 31))
  end

  test "repeat until is inclusive and multi-day occurrences keep their duration" do
    trip = event(starts_on: Date.new(2025, 12, 30), ends_on: Date.new(2026, 1, 2), repeat_until: Date.new(2026, 12, 30))
    range = Date.new(2027, 1, 1)..Date.new(2027, 1, 2)
    occurrence = Family::Event.occurrences_between(range).find { |e| e.series == trip }
    assert_equal Date.new(2026, 12, 30), occurrence.starts_on
    assert_equal Date.new(2027, 1, 2), occurrence.last_day
    assert_equal 4, occurrence.days.count
    assert_empty trip.occurrence_dates(Date.new(2027, 12, 1)..Date.new(2028, 1, 3))
  end

  test "non repeating events appear once" do
    once = event(repeat_frequency: "none")
    assert_equal [once.starts_on], once.occurrence_dates(once.starts_on..once.starts_on + 800)
    assert_empty once.occurrence_dates(once.starts_on + 1..once.starts_on + 800)
  end

  test "invalid repeat settings are rejected" do
    assert_not Family::Event.new(title: "Bad", starts_on: Family.today, repeat_frequency: "hourly").valid?
    assert_not Family::Event.new(title: "Bad", starts_on: Family.today, repeat_frequency: "weekly", repeat_until: Family.today - 1).valid?
  end

  test "upcoming includes repeated occurrences in date order without generating rows" do
    travel_to Time.zone.local(2030, 5, 10, 12) do
      birthday = event
      event(title: "Far future", starts_on: Date.new(2040, 1, 1), repeat_frequency: "none")
      before = Family::Event.count
      upcoming = Family::Event.upcoming_occurrences(limit: 3)
      assert_equal [Date.new(2030, 5, 12), Date.new(2031, 5, 12), Date.new(2032, 5, 12)], upcoming.map(&:starts_on)
      assert_equal [birthday.id], upcoming.map { |e| e.series.id }.uniq
      assert_equal before, Family::Event.count
    end
  end

  test "moved and cancelled occurrences replace their original dates" do
    birthday = event
    original = Date.new(2026, 5, 12)
    birthday.recurrence_overrides.create!(title: "Party", original_on: original, starts_on: original + 1)
    birthday.recurrence_overrides.create!(title: "Skip", original_on: original.advance(years: 1), starts_on: original.advance(years: 1), cancelled: true)
    assert_empty Family::Event.occurrences_between(original..original)
    assert_equal ["Party"], Family::Event.occurrences_between(original + 1..original + 1).map(&:title)
    assert_empty Family::Event.occurrences_between(original.advance(years: 1)..original.advance(years: 1))
    assert_equal original, birthday.occurrence_on(original).original_on
    assert_nil birthday.occurrence_on(original.advance(years: 1))
  end

  test "moved occurrence is visible even before the series start" do
    birthday = event(starts_on: Date.new(2030, 5, 12))
    birthday.recurrence_overrides.create!(title: "Early party", original_on: birthday.starts_on, starts_on: Date.new(2030, 5, 1))
    assert_equal ["Early party"], Family::Event.occurrences_between(Date.new(2030, 5, 1)..Date.new(2030, 5, 1)).map(&:title)
  end

  test "series deletion removes its individual changes" do
    birthday = event
    birthday.recurrence_overrides.create!(title: "Skip", original_on: birthday.starts_on, starts_on: birthday.starts_on, cancelled: true)
    assert_difference -> { Family::Event.count }, -2 do
      birthday.destroy!
    end
  end
  test "upcoming skips cancellations and orders moved occurrences by their new dates" do
    travel_to Time.zone.local(2030, 5, 10, 12) do
      birthday = event
      birthday.recurrence_overrides.create!(title: "Cancelled", original_on: Date.new(2030, 5, 12), starts_on: Date.new(2030, 5, 12), cancelled: true)
      birthday.recurrence_overrides.create!(title: "Early party", original_on: Date.new(2031, 5, 12), starts_on: Date.new(2030, 5, 11))
      assert_equal [Date.new(2030, 5, 11), Date.new(2032, 5, 12)], Family::Event.upcoming_occurrences(limit: 2).map(&:starts_on)
    end
  end

  test "series edits retain exceptions and an earlier cutoff hides later exceptions" do
    birthday = event
    original = Date.new(2027, 5, 12)
    birthday.recurrence_overrides.create!(title: "Party", original_on: original, starts_on: original + 1)
    birthday.update!(title: "Annual birthday", repeat_until: original)
    assert_equal "Party", birthday.occurrence_on(original).title
    assert_not birthday.update(starts_on: birthday.starts_on + 1)
    birthday.reload.update!(repeat_until: original - 1)
    assert_empty Family::Event.occurrences_between(original..original + 1)
    assert_nil birthday.occurrence_on(original)
  end

  test "an ordinary event can become a series and stop repeating before exceptions exist" do
    birthday = event(repeat_frequency: "none")
    birthday.update!(repeat_frequency: "annually")
    assert birthday.occurrence_on(Date.new(2030, 5, 12))
    birthday.update!(repeat_frequency: "none", repeat_until: birthday.starts_on - 1)
    assert_nil birthday.repeat_until
    assert_nil birthday.occurrence_on(Date.new(2030, 5, 12))
  end

end
