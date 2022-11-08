require "application_system_test_case"

class BookingDaysTest < ApplicationSystemTestCase
  setup do
    @booking_day = booking_days(:one)
  end

  test "visiting the index" do
    visit booking_days_url
    assert_selector "h1", text: "Booking Days"
  end

  test "creating a Booking day" do
    visit booking_days_url
    click_on "New Booking Day"

    fill_in "Day", with: @booking_day.day
    fill_in "Day rate", with: @booking_day.day_rate
    check "Extra b" if @booking_day.extra_b
    fill_in "Extra i", with: @booking_day.extra_i
    fill_in "Extra s", with: @booking_day.extra_s
    fill_in "Property", with: @booking_day.property_id
    click_on "Create Booking day"

    assert_text "Booking day was successfully created"
    click_on "Back"
  end

  test "updating a Booking day" do
    visit booking_days_url
    click_on "Edit", match: :first

    fill_in "Day", with: @booking_day.day
    fill_in "Day rate", with: @booking_day.day_rate
    check "Extra b" if @booking_day.extra_b
    fill_in "Extra i", with: @booking_day.extra_i
    fill_in "Extra s", with: @booking_day.extra_s
    fill_in "Property", with: @booking_day.property_id
    click_on "Update Booking day"

    assert_text "Booking day was successfully updated"
    click_on "Back"
  end

  test "destroying a Booking day" do
    visit booking_days_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Booking day was successfully destroyed"
  end
end
