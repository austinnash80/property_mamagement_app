require "test_helper"

class BookingDaysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @booking_day = booking_days(:one)
  end

  test "should get index" do
    get booking_days_url
    assert_response :success
  end

  test "should get new" do
    get new_booking_day_url
    assert_response :success
  end

  test "should create booking_day" do
    assert_difference('BookingDay.count') do
      post booking_days_url, params: { booking_day: { day: @booking_day.day, day_rate: @booking_day.day_rate, extra_b: @booking_day.extra_b, extra_i: @booking_day.extra_i, extra_s: @booking_day.extra_s, property_id: @booking_day.property_id } }
    end

    assert_redirected_to booking_day_url(BookingDay.last)
  end

  test "should show booking_day" do
    get booking_day_url(@booking_day)
    assert_response :success
  end

  test "should get edit" do
    get edit_booking_day_url(@booking_day)
    assert_response :success
  end

  test "should update booking_day" do
    patch booking_day_url(@booking_day), params: { booking_day: { day: @booking_day.day, day_rate: @booking_day.day_rate, extra_b: @booking_day.extra_b, extra_i: @booking_day.extra_i, extra_s: @booking_day.extra_s, property_id: @booking_day.property_id } }
    assert_redirected_to booking_day_url(@booking_day)
  end

  test "should destroy booking_day" do
    assert_difference('BookingDay.count', -1) do
      delete booking_day_url(@booking_day)
    end

    assert_redirected_to booking_days_url
  end
end
