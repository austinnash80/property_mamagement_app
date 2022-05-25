class PagesController < ApplicationController
  def homepage
    @properties = Property.all
  end

  def manage_property
    dates
    property_booking = Booking.where(property_id: params['property'])
    property_accounting = Accounting.where(property_id: params['property'])
    #Expenses
    @expenses_previous_year = property_accounting.where(r_e: 'Expense').where(record_date: @previous_year_s..@previous_year_e).sum(:amount)
    @expenses_current_year = property_accounting.where(r_e: 'Expense').where(record_date: @current_year_s..@current_year_e).sum(:amount)
    @expenses_current_month = property_accounting.where(r_e: 'Expense').where(record_date: @current_month_s..@current_month_e).sum(:amount)
    @expenses_previous_month = property_accounting.where(r_e: 'Expense').where(record_date: @previous_month_s..@previous_month_e).sum(:amount)
    #Revenue
    @revenue_previous_year = property_accounting.where(r_e: 'Revenue').where(record_date: @previous_year_s..@previous_year_e).sum(:amount)
    @revenue_current_year = property_accounting.where(r_e: 'Revenue').where(record_date: @current_year_s..@current_year_e).sum(:amount)
    @revenue_current_month = property_accounting.where(r_e: 'Revenue').where(record_date: @current_month_s..@current_month_e).sum(:amount)
    @revenue_previous_month = property_accounting.where(r_e: 'Revenue').where(record_date: @previous_month_s..@previous_month_e).sum(:amount)

    # Bookings
    @bookings_previous_year = property_booking.where(check_in: @previous_year_s..@previous_year_e).count
    @nights_previous_year = property_booking.where(check_in: @previous_year_s..@previous_year_e).sum(:nights)
    @bookings_current_year = property_booking.where(check_in: @current_year_s..@current_year_e).count
    @nights_current_year = property_booking.where(check_in: @current_year_s..@current_year_e).sum(:nights)
    @bookings_current_month = property_booking.where(check_in: @current_month_s..@current_month_e).count
    @nights_current_month = property_booking.where(check_in: @current_month_s..@current_month_e).sum(:nights)
    @bookings_previous_month = property_booking.where(check_in: @previous_month_s..@previous_month_e).count
    @nights_previous_month = property_booking.where(check_in: @previous_month_s..@previous_month_e).sum(:nights)

  end

  def dates
    @previous_year_s = (Date.today - 1.year).beginning_of_year
    @previous_year_e = (Date.today - 1.year).end_of_year
    @current_year_s = Date.today.beginning_of_year
    @current_year_e = Date.today.end_of_year
    @current_month_s = Date.today.beginning_of_month
    @current_month_e = Date.today.end_of_month
    @previous_month_s = (Date.today - 1.month).beginning_of_month
    @previous_month_e = (Date.today - 1.month).end_of_month
  end
end
