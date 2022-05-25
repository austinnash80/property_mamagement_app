require "test_helper"

class AccountingListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @accounting_list = accounting_lists(:one)
  end

  test "should get index" do
    get accounting_lists_url
    assert_response :success
  end

  test "should get new" do
    get new_accounting_list_url
    assert_response :success
  end

  test "should create accounting_list" do
    assert_difference('AccountingList.count') do
      post accounting_lists_url, params: { accounting_list: { accounting_type: @accounting_list.accounting_type, amount: @accounting_list.amount, notes: @accounting_list.notes, vendor: @accounting_list.vendor } }
    end

    assert_redirected_to accounting_list_url(AccountingList.last)
  end

  test "should show accounting_list" do
    get accounting_list_url(@accounting_list)
    assert_response :success
  end

  test "should get edit" do
    get edit_accounting_list_url(@accounting_list)
    assert_response :success
  end

  test "should update accounting_list" do
    patch accounting_list_url(@accounting_list), params: { accounting_list: { accounting_type: @accounting_list.accounting_type, amount: @accounting_list.amount, notes: @accounting_list.notes, vendor: @accounting_list.vendor } }
    assert_redirected_to accounting_list_url(@accounting_list)
  end

  test "should destroy accounting_list" do
    assert_difference('AccountingList.count', -1) do
      delete accounting_list_url(@accounting_list)
    end

    assert_redirected_to accounting_lists_url
  end
end
