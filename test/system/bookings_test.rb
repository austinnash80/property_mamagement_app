require "application_system_test_case"

class BookingsTest < ApplicationSystemTestCase
  setup do
    @booking = bookings(:one)
  end

  test "visiting the index" do
    visit bookings_url
    assert_selector "h1", text: "Bookings"
  end

  test "creating a Booking" do
    visit bookings_url
    click_on "New Booking"

    fill_in "Check in", with: @booking.check_in
    fill_in "Check out", with: @booking.check_out
    fill_in "Confirmation code", with: @booking.confirmation_code
    fill_in "Guest name", with: @booking.guest_name
    fill_in "Nights", with: @booking.nights
    fill_in "Notes", with: @booking.notes
    fill_in "Payout", with: @booking.payout
    fill_in "Platform", with: @booking.platform
    fill_in "Property", with: @booking.property_id
    click_on "Create Booking"

    assert_text "Booking was successfully created"
    click_on "Back"
  end

  test "updating a Booking" do
    visit bookings_url
    click_on "Edit", match: :first

    fill_in "Check in", with: @booking.check_in
    fill_in "Check out", with: @booking.check_out
    fill_in "Confirmation code", with: @booking.confirmation_code
    fill_in "Guest name", with: @booking.guest_name
    fill_in "Nights", with: @booking.nights
    fill_in "Notes", with: @booking.notes
    fill_in "Payout", with: @booking.payout
    fill_in "Platform", with: @booking.platform
    fill_in "Property", with: @booking.property_id
    click_on "Update Booking"

    assert_text "Booking was successfully updated"
    click_on "Back"
  end

  test "destroying a Booking" do
    visit bookings_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Booking was successfully destroyed"
  end
end
