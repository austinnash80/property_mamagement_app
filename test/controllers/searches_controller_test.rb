require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @search = searches(:one)
  end

  test "should get index" do
    get searches_url
    assert_response :success
  end

  test "should get new" do
    get new_search_url
    assert_response :success
  end

  test "should create search" do
    assert_difference('Search.count') do
      post searches_url, params: { search: { accounting_type: @search.accounting_type, date_range_a: @search.date_range_a, date_range_b: @search.date_range_b, description: @search.description, field_1: @search.field_1, field_2: @search.field_2, field_3: @search.field_3, property: @search.property } }
    end

    assert_redirected_to search_url(Search.last)
  end

  test "should show search" do
    get search_url(@search)
    assert_response :success
  end

  test "should get edit" do
    get edit_search_url(@search)
    assert_response :success
  end

  test "should update search" do
    patch search_url(@search), params: { search: { accounting_type: @search.accounting_type, date_range_a: @search.date_range_a, date_range_b: @search.date_range_b, description: @search.description, field_1: @search.field_1, field_2: @search.field_2, field_3: @search.field_3, property: @search.property } }
    assert_redirected_to search_url(@search)
  end

  test "should destroy search" do
    assert_difference('Search.count', -1) do
      delete search_url(@search)
    end

    assert_redirected_to searches_url
  end
end
