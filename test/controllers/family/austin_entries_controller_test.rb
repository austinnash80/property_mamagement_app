require "test_helper"

class Family::AustinEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "austin-test@example.com", password: "test-pass", role: "family")
    post login_path, params: { email: @user.email, password: "test-pass" }
  end

  test "lists entries under their section with phone numbers tappable" do
    Family::AustinEntry.create!(title: "Doctor", value: "(555) 010-2020", section: "Doctors")
    get family_austin_entries_path
    assert_response :success
    assert_select "h3", text: "Doctors"
    assert_select "a[href='tel:5550102020']", text: "(555) 010-2020"
  end

  test "adds, edits and deletes an entry" do
    assert_difference -> { Family::AustinEntry.count }, 1 do
      post family_austin_entries_path, params: {
        family_austin_entry: { title: "Home address", value: "1 Main St", section: "Contacts & addresses" }
      }
    end
    assert_redirected_to family_austin_entries_path

    entry = Family::AustinEntry.last
    patch family_austin_entry_path(entry), params: { family_austin_entry: { title: "Home" } }
    assert_redirected_to family_austin_entries_path
    assert_equal "Home", entry.reload.title

    assert_difference -> { Family::AustinEntry.count }, -1 do
      delete family_austin_entry_path(entry)
    end
  end

  test "rejects an entry without a title and reopens the add form" do
    post family_austin_entries_path, params: { family_austin_entry: { title: "", section: "Other" } }
    assert_response :unprocessable_entity
    assert_select "dialog[data-open-on-load]"
  end
  test "Austin is linked from the dashboard and navigation" do
    get family_root_path
    assert_response :success
    assert_select "h5", text: "Austin"
    assert_select "a[href=?]", family_austin_entries_path
    get family_austin_entries_path
    assert_select "a.active[href=?]", family_austin_entries_path
  end

  test "keeps Austin entries separate from Andie" do
    Family::AndieEntry.create!(title: "Andie only", section: "Health")
    Family::AustinEntry.create!(title: "Austin only", section: "Health")
    get family_austin_entries_path
    assert_select ".fa-ref-title", text: "Austin only"
    assert_select ".fa-ref-title", text: "Andie only", count: 0
  end

  test "rejects unknown sections" do
    assert_no_difference -> { Family::AustinEntry.count } do
      post family_austin_entries_path, params: {
        family_austin_entry: { title: "Doctor", section: "Unknown" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "requires login" do
    delete logout_path
    get family_austin_entries_path
    assert_redirected_to login_path
  end

end
