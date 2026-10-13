require "test_helper"

class Family::RaeEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "rae-test@example.com", password: "test-pass", role: "family")
    post login_path, params: { email: @user.email, password: "test-pass" }
  end

  test "lists entries under their section with phone numbers tappable" do
    Family::RaeEntry.create!(title: "Vet", value: "(555) 010-2020", section: "Vet")
    get family_rae_entries_path
    assert_response :success
    assert_select "h3", text: "Vet"
    assert_select "a[href='tel:5550102020']", text: "(555) 010-2020"
  end

  test "adds, edits and deletes an entry" do
    assert_difference -> { Family::RaeEntry.count }, 1 do
      post family_rae_entries_path, params: {
        family_rae_entry: { title: "Food", value: "Kibble, 2 cups a day", section: "Food & meds" }
      }
    end
    assert_redirected_to family_rae_entries_path

    entry = Family::RaeEntry.last
    patch family_rae_entry_path(entry), params: { family_rae_entry: { title: "Dinner" } }
    assert_redirected_to family_rae_entries_path
    assert_equal "Dinner", entry.reload.title

    assert_difference -> { Family::RaeEntry.count }, -1 do
      delete family_rae_entry_path(entry)
    end
  end

  test "rejects an entry without a title and reopens the add form" do
    post family_rae_entries_path, params: { family_rae_entry: { title: "", section: "Other" } }
    assert_response :unprocessable_entity
    assert_select "dialog[data-open-on-load]"
  end
end
