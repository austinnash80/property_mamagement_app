require "application_system_test_case"

class SearchesTest < ApplicationSystemTestCase
  setup do
    @search = searches(:one)
  end

  test "visiting the index" do
    visit searches_url
    assert_selector "h1", text: "Searches"
  end

  test "creating a Search" do
    visit searches_url
    click_on "New Search"

    fill_in "Accounting type", with: @search.accounting_type
    fill_in "Date range a", with: @search.date_range_a
    fill_in "Date range b", with: @search.date_range_b
    fill_in "Description", with: @search.description
    fill_in "Field 1", with: @search.field_1
    fill_in "Field 2", with: @search.field_2
    fill_in "Field 3", with: @search.field_3
    fill_in "Property", with: @search.property
    click_on "Create Search"

    assert_text "Search was successfully created"
    click_on "Back"
  end

  test "updating a Search" do
    visit searches_url
    click_on "Edit", match: :first

    fill_in "Accounting type", with: @search.accounting_type
    fill_in "Date range a", with: @search.date_range_a
    fill_in "Date range b", with: @search.date_range_b
    fill_in "Description", with: @search.description
    fill_in "Field 1", with: @search.field_1
    fill_in "Field 2", with: @search.field_2
    fill_in "Field 3", with: @search.field_3
    fill_in "Property", with: @search.property
    click_on "Update Search"

    assert_text "Search was successfully updated"
    click_on "Back"
  end

  test "destroying a Search" do
    visit searches_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Search was successfully destroyed"
  end
end
