require "test_helper"

class Family::AndieEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "andie-test@example.com", password: "test-pass", role: "family")
    post login_path, params: { email: @user.email, password: "test-pass" }
  end

  test "lists entries under their section with phone numbers tappable" do
    Family::AndieEntry.create!(title: "Pediatrician", value: "(555) 010-2020", section: "Doctors")
    get family_andie_entries_path
    assert_response :success
    assert_select "h3", text: "Doctors"
    assert_select "a[href='tel:5550102020']", text: "(555) 010-2020"
  end

  test "adds, edits and deletes an entry" do
    assert_difference -> { Family::AndieEntry.count }, 1 do
      post family_andie_entries_path, params: {
        family_andie_entry: { title: "Home address", value: "1 Main St", section: "Contacts & addresses" }
      }
    end
    assert_redirected_to family_andie_entries_path

    entry = Family::AndieEntry.last
    patch family_andie_entry_path(entry), params: { family_andie_entry: { title: "Home" } }
    assert_redirected_to family_andie_entries_path
    assert_equal "Home", entry.reload.title

    assert_difference -> { Family::AndieEntry.count }, -1 do
      delete family_andie_entry_path(entry)
    end
  end

  test "rejects an entry without a title and reopens the add form" do
    post family_andie_entries_path, params: { family_andie_entry: { title: "", section: "Other" } }
    assert_response :unprocessable_entity
    assert_select "dialog[data-open-on-load]"
  end
end
