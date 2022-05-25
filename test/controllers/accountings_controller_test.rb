require "test_helper"

class AccountingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @accounting = accountings(:one)
  end

  test "should get index" do
    get accountings_url
    assert_response :success
  end

  test "should get new" do
    get new_accounting_url
    assert_response :success
  end

  test "should create accounting" do
    assert_difference('Accounting.count') do
      post accountings_url, params: { accounting: { amount: @accounting.amount, description: @accounting.description, notes: @accounting.notes, property_id: @accounting.property_id, r_e: @accounting.r_e } }
    end

    assert_redirected_to accounting_url(Accounting.last)
  end

  test "should show accounting" do
    get accounting_url(@accounting)
    assert_response :success
  end

  test "should get edit" do
    get edit_accounting_url(@accounting)
    assert_response :success
  end

  test "should update accounting" do
    patch accounting_url(@accounting), params: { accounting: { amount: @accounting.amount, description: @accounting.description, notes: @accounting.notes, property_id: @accounting.property_id, r_e: @accounting.r_e } }
    assert_redirected_to accounting_url(@accounting)
  end

  test "should destroy accounting" do
    assert_difference('Accounting.count', -1) do
      delete accounting_url(@accounting)
    end

    assert_redirected_to accountings_url
  end
end
