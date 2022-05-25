require "application_system_test_case"

class AccountingsTest < ApplicationSystemTestCase
  setup do
    @accounting = accountings(:one)
  end

  test "visiting the index" do
    visit accountings_url
    assert_selector "h1", text: "Accountings"
  end

  test "creating a Accounting" do
    visit accountings_url
    click_on "New Accounting"

    fill_in "Amount", with: @accounting.amount
    fill_in "Description", with: @accounting.description
    fill_in "Notes", with: @accounting.notes
    fill_in "Property", with: @accounting.property_id
    fill_in "R e", with: @accounting.r_e
    click_on "Create Accounting"

    assert_text "Accounting was successfully created"
    click_on "Back"
  end

  test "updating a Accounting" do
    visit accountings_url
    click_on "Edit", match: :first

    fill_in "Amount", with: @accounting.amount
    fill_in "Description", with: @accounting.description
    fill_in "Notes", with: @accounting.notes
    fill_in "Property", with: @accounting.property_id
    fill_in "R e", with: @accounting.r_e
    click_on "Update Accounting"

    assert_text "Accounting was successfully updated"
    click_on "Back"
  end

  test "destroying a Accounting" do
    visit accountings_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Accounting was successfully destroyed"
  end
end
