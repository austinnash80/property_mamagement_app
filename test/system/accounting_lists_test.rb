require "application_system_test_case"

class AccountingListsTest < ApplicationSystemTestCase
  setup do
    @accounting_list = accounting_lists(:one)
  end

  test "visiting the index" do
    visit accounting_lists_url
    assert_selector "h1", text: "Accounting Lists"
  end

  test "creating a Accounting list" do
    visit accounting_lists_url
    click_on "New Accounting List"

    fill_in "Accounting type", with: @accounting_list.accounting_type
    fill_in "Amount", with: @accounting_list.amount
    fill_in "Notes", with: @accounting_list.notes
    fill_in "Vendor", with: @accounting_list.vendor
    click_on "Create Accounting list"

    assert_text "Accounting list was successfully created"
    click_on "Back"
  end

  test "updating a Accounting list" do
    visit accounting_lists_url
    click_on "Edit", match: :first

    fill_in "Accounting type", with: @accounting_list.accounting_type
    fill_in "Amount", with: @accounting_list.amount
    fill_in "Notes", with: @accounting_list.notes
    fill_in "Vendor", with: @accounting_list.vendor
    click_on "Update Accounting list"

    assert_text "Accounting list was successfully updated"
    click_on "Back"
  end

  test "destroying a Accounting list" do
    visit accounting_lists_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Accounting list was successfully destroyed"
  end
end
